# frozen_string_literal: true

module Substrate
  module Client
    class << self
      def get_metadata(url, at = nil)
        hex = Substrate::RPC.state_getMetadata(url, at)
        Metadata.decode_metadata(hex.strip.to_bytes)
      end

      def query_storage_at(url, storage_keys, type_id, default, registry, at = nil)
        result = Substrate::RPC.state_queryStorageAt(url, storage_keys, at)
        result.map do |item|
          item['changes'].map do |change|
            storage_key = change[0]
            data = change[1] || default
            storage = data.nil? ? nil : PortableCodec.decode(type_id, data.to_bytes, registry)[0]
            { storage_key: storage_key, storage: storage }
          end
        end.flatten
      end

      def get_storage_keys_by_partial_key(url, partial_storage_key, start_key = nil, at = nil)
        storage_keys = Substrate::RPC.state_getKeysPaged(url, partial_storage_key, 1000, start_key, at)
        if storage_keys.length == 1000
          storage_keys + get_storage_keys_by_partial_key(url, partial_storage_key, storage_keys.last, at)
        else
          storage_keys
        end
      end

      def get_storages_by_partial_key(url, partial_storage_key, type_id_of_value, default, registry, at = nil)
        storage_keys = get_storage_keys_by_partial_key(url, partial_storage_key, partial_storage_key, at)
        storage_keys.each_slice(250).map do |slice|
          query_storage_at(
            url,
            slice,
            type_id_of_value,
            default,
            registry,
            at
          )
        end.flatten
      end

      # type_id: result type id
      def get_storage(url, storage_key, type_id, default, registry, at = nil)
        data = Substrate::RPC.state_getStorage(url, storage_key, at) || default
        return nil if data.nil?

        PortableCodec.decode(type_id, data.to_bytes, registry)[0]
      end

      # 1. Plain
      #   key:   nil
      #   value: { type: 3, modifier: 'Default', callback: '' }
      #
      # 2. Map
      #   key:   { value: value, type: 0, hashers: ['Blake2128Concat'] }
      #   value: { type: 3, modifier: 'Default', callback: '' }
      #
      # 3. Map, but key.value is nil
      #   key:   { value: nil, type: 0, hashers: ['Blake2128Concat'] }
      #   value: { type: 3, modifier: 'Default', callback: '' }
      #
      # example:
      #   'System',
      #   'Account',
      #   key = {
      #     value: [['0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'.to_bytes]], # [AccountId]
      #     type: 0,
      #     hashers: ['Blake2128Concat']
      #   },
      #   value = {
      #     type: 3,
      #     modifier: 'Default',
      #     callback: '0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
      #   },
      #   ..
      #
      def get_storage2(url, pallet_name, item_name, key, value, registry, at = nil)
        # map, but no key's value provided. get all storages under the partial storage key
        if !key.nil? && key[:value].nil?
          partial_storage_key = StorageHelper.encode_storage_key(pallet_name, item_name).to_hex
          get_storages_by_partial_key(
            url,
            partial_storage_key,
            value[:type],
            value[:modifier] == 'Default' ? value[:fallback] : nil,
            registry,
            at
          )
        else
          params = (StorageHelper.build_params(key[:value], key[:type], key[:hashers], registry) unless key.nil?)
          storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, params, registry).to_hex
          get_storage(
            url,
            storage_key,
            value[:type],
            value[:modifier] == 'Default' ? value[:fallback] : nil,
            registry,
            at
          )
        end
      end

      def get_storage3(url, pallet_name, item_name, value_of_key, metadata, at = nil)
        raise 'metadata should not be nil' if metadata.nil?

        registry = Metadata.build_registry(metadata)
        item = Metadata.get_storage_item(pallet_name, item_name, metadata)

        modifier = item._get(:modifier) # Default | Optional
        fallback = item._get(:fallback)
        type = item._get(:type)

        plain = type._get(:plain)
        map = type._get(:map)
        key, value =
          if plain
            [
              nil,
              { type: plain, modifier: modifier, fallback: fallback }
            ]
          elsif map
            [
              { value: value_of_key, type: map._get(:key), hashers: map._get(:hashers) },
              { type: map._get(:value), modifier: modifier, fallback: fallback }
            ]
          else
            raise 'NoSuchStorageType'
          end
        get_storage2(url, pallet_name, item_name, key, value, registry, at)
      end
    end
  end
end
