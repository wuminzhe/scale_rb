# frozen_string_literal: true

module ScaleRb
  module StorageHelper
    class << self
      # key example: {:value=>[0], :type=>4, :hashers=>["Twox64Concat"]}
      def encode_storage_key(pallet_name, item_name, key = nil, registry = nil)
        storage_key = Hasher.twox128(pallet_name) + Hasher.twox128(item_name)

        if key && registry

          key_types, key_values, key_hashers =
            if key[:hashers].length == 1
              # {:value=>[0], :type=>4, :hashers=>["Twox64Concat"]}
              # type 4 is Uint32
              [
                [key[:type]],
                key[:value],
                key[:hashers]
              ]
            else
              [
                registry[key[:type]].tuple.first(key[:value].length),
                key[:value],
                key[:hashers].first(key[:value].length)
              ]
            end

          ScaleRb.logger.debug "encode_storage_key: key_values: #{key_values.inspect}, key_types: #{key_types.inspect}, key_hashers: #{key_hashers.inspect}"

          if key_types.class != key_values.class || key_types.length != key_values.length
            raise "Key's value doesn't match key's type, key's value: #{key_values.inspect}, but key's type: #{key_types.inspect}. Please check your key's value."
          end

          storage_key + _encode_types_with_hashers(key_types, key_values, registry, key_hashers)
        else
          storage_key
        end
      end

      def _encode_types_with_hashers(type_ids, values, registry, hashers)
        if !hashers.nil? && hashers.length != type_ids.length
          raise "type_ids length: #{type_ids.length}, hashers length: #{hashers.length}"
        end

        type_ids
          .map.with_index { |type_id, i| ScaleRb::Codec.encode(type_id, values[i], registry) }
          .each_with_index.reduce([]) do |memo, (bytes, i)|
            memo + Hasher.apply_hasher(hashers[i], bytes)
          end
      end

      # data: hex string
      # type: portable type id
      # optional: boolean
      # fallback: hex string or u8array
      # returns nil or data
      def decode_storage(data, type, optional, fallback, registry)
        bytes = data.nil? ? nil : Utils.hex_to_u8a(data)
        bytes = bytes.nil? ?
          (optional ? nil : (fallback.is_a?(Array) ? fallback : Utils.hex_to_u8a(fallback))) :
          bytes

        ScaleRb::Codec.decode(type, bytes, registry)[0] if bytes
      end

      # storage_item: the storage item from metadata
      def decode_storage2(data, storage_item, registry)
        modifier = storage_item._get(:modifier) # Default | Optional
        fallback = storage_item._get(:fallback)
        type = storage_item._get(:type, :plain) || storage_item._get(:type, :map, :value)
        decode_storage(data, type, modifier == 'Optional', fallback, registry)
      end

      def decode_storage3(data, pallet_name, item_name, metadata)
        registry = metadata.build_registry
        storage_item = metadata.storage(pallet_name, item_name)
        decode_storage2(data, storage_item, registry)
      end
    end
  end
end
