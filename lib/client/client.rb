# frozen_string_literal: true

module Client
  class << self
    def get_metadata(url, at = nil)
      hex = RPC.state_getMetadata(url, at)
      Metadata.decode_metadata(hex.strip.to_bytes)
    end

    # type_id: result type id
    def get_storage(url, storage_key, type_id, default, registry, at = nil)
      data = RPC.state_getStorage(url, storage_key, at) || default
      return nil if data.nil?

      PortableCodec.decode(type_id, data.to_bytes, registry)[0]
    end

    # key:   { value: .., type: 0, hashers: ['Blake2128Concat'] } | nil
    # value: { type: 3, modifier: 'Default', callback: '' }
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
    def get_storage2(url, pallet_name, item_name, key, value, registry, at = nil)
      params = (StorageHelper.build_params(key[:value], key[:type], key[:hashers], registry) if key)

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

    def get_storage3(url, pallet_name, item_name, key_value, metadata, at = nil)
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
            { value: key_value, type: map._get(:key), hashers: map._get(:hashers) },
            { type: map._get(:value), modifier: modifier, fallback: fallback }
          ]
        else
          raise 'NoSuchStorageType'
        end
      get_storage2(url, pallet_name, item_name, key, value, registry, at)
    end
  end
end
