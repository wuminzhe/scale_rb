# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

module ScaleRb
  module HttpClient
    extend RpcRequestBuilder

    class << self
      def request(url, body)
        uri = URI(url)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = body
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.instance_of? URI::HTTPS
        res = http.request(req)
        # puts res unless res.is_a?(Net::HTTPSuccess)

        result = JSON.parse(res.body)
        raise result['error'] if result['error']

        result['result']
      end

      def json_rpc_call(url, method, *params)
        body = build_json_rpc_body(method, params, Time.now.to_i)
        request(url, body)
      end

      def respond_to_missing?(*_args)
        true
      end

      def method_missing(method, *args)
        json_rpc_call(args[0], method, *args[1..])
      end

      def get_metadata(url, at = nil)
        hex = state_getMetadata(url, at)
        Metadata.decode_metadata(hex.strip.to_bytes)
      end

      def query_storage_at(url, storage_keys, type_id, default, registry, at = nil)
        result = state_queryStorageAt(url, storage_keys, at)
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
        storage_keys = state_getKeysPaged(url, partial_storage_key, 1000, start_key, at)
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
      def get_storage(url, pallet_name, item_name, key, value, registry, at = nil)
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
          storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry).to_hex
          data = state_getStorage(url, storage_key, at)
          StorageHelper.decode_storage(data, value[:type], value[:modifier] == 'Optional', value[:fallback], registry)
        end
      end

      def get_storage2(url, pallet_name, item_name, value_of_key, metadata, at = nil)
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
        get_storage(url, pallet_name, item_name, key, value, registry, at)
      end
    end
  end
end