module ScaleRb
  module HttpClient
    class << self
      # get_storage3 is a more ruby style function
      #
      # pallet_name and storage_name is pascal style like 'darwinia_staking'
      def get_storage3(url, pallet_name, storage_name, key_part1: nil, key_part2: nil, metadata: nil, at: nil)
        # Get metadata if not provided, and cache it.
        # The default dir is `metadata` dir under the caller's dir.
        # You can change it by setting `SCALE_RB_METADATA_DIR` env variable
        metadata = get_metadata_cached(url, at: at) if metadata.nil?

        pallet_name = to_pascal pallet_name
        storage_name = to_pascal storage_name
        ScaleRb.logger.debug "#{pallet_name}.#{storage_name}(#{[key_part1, key_part2].compact.join(', ')})"

        key = [key_part1, key_part2].compact.map { |part_of_key| c(part_of_key) }
        ScaleRb.logger.debug "converted key: #{key}"

        get_storage2(
          url,
          pallet_name,
          storage_name,
          key,
          metadata,
          at
        )
      end

      private

      def query_storage_at(url, storage_keys, type_id, default, registry, at = nil)
        result = state_queryStorageAt(url, storage_keys, at)
        result.map do |item|
          item['changes'].map do |change|
            storage_key = change[0]
            data = change[1] || default
            storage = data.nil? ? nil : PortableCodec.decode(type_id, data._to_bytes, registry)[0]
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
      #     value: [['0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'._to_bytes]], # [AccountId]
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
      # TODO: part of the key is provided, but not all
      def get_storage(url, pallet_name, item_name, key, value, registry, at = nil)
        if key
          if key[:value].nil? || key[:value].empty?
            # map, but no key's value provided. get all storages under the partial storage key
            partial_storage_key = StorageHelper.encode_storage_key(pallet_name, item_name)._to_hex
            get_storages_by_partial_key(
              url,
              partial_storage_key,
              value[:type],
              value[:modifier] == 'Default' ? value[:fallback] : nil,
              registry,
              at
            )
          elsif key[:value].length != key[:hashers].length
            # map with multi parts, but not have all values
            partial_storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry)._to_hex
            get_storages_by_partial_key(
              url,
              partial_storage_key,
              value[:type],
              value[:modifier] == 'Default' ? value[:fallback] : nil,
              registry,
              at
            )
          end
        else
          storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry)._to_hex
          data = state_getStorage(url, storage_key, at)
          StorageHelper.decode_storage(data, value[:type], value[:modifier] == 'Optional', value[:fallback], registry)
        end
      end

      def get_storage2(url, pallet_name, item_name, value_of_key, metadata, at = nil)
        raise 'Metadata should not be nil' if metadata.nil?

        registry = Metadata.build_registry(metadata)
        item = Metadata.get_storage_item(
          pallet_name, item_name, metadata
        )
        raise "No such storage item: `#{pallet_name}`.`#{item_name}`" if item.nil?

        modifier = item._get(:modifier) # Default | Optional
        fallback = item._get(:fallback)
        type = item._get(:type)

        plain = type._get(:plain)
        map = type._get(:map)
        # debug

        key, value =
          if plain
            [
              nil,
              { type: plain,
                modifier: modifier, fallback: fallback }
            ]
          elsif map
            [
              { value: value_of_key,
                type: map._get(:key), hashers: map._get(:hashers) },
              { type: map._get(:value),
                modifier: modifier, fallback: fallback }
            ]
          else
            raise 'NoSuchStorageType'
          end
        get_storage(url, pallet_name, item_name, key, value, registry, at)
      end

      def to_pascal(str)
        str.split('_').collect(&:capitalize).join
      end

      # convert key to byte array
      def c(key)
        if key.start_with?('0x')
          key._to_bytes
        elsif key.to_i.to_s == key # check if key is a number
          key.to_i
        else
          key
        end
      end
    end
  end
end
