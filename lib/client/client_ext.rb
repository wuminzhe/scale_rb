module ScaleRb
  module ClientExt
    def get_metadata(block_hash)
      dir = ENV['SCALE_RB_METADATA_DIR'] || File.join(Dir.pwd, 'metadata')

      get_metadata_by_block_hash(dir, block_hash)
    end

    # get storage at block_hash
    def get_storage(block_hash, pallet_name, storage_name, key_part1: nil, key_part2: nil)
      metadata = get_metadata(block_hash)

      # storeage item
      pallet_name = to_pascal pallet_name
      storage_name = to_pascal storage_name

      # storage param
      key = [key_part1, key_part2].compact
      ScaleRb.logger.debug "#{pallet_name}.#{storage_name}(#{key.join(', ')})"
      key = key.map { |part_of_key| c(part_of_key) }
      ScaleRb.logger.debug "converted key: #{key}"

      get_storage2(
        block_hash, # at
        pallet_name,
        storage_name,
        key,
        metadata
      )
    end

    private

    def get_metadata_by_block_hash(cache_dir, block_hash)
      # Get metadata from cache if it exists
      runtime_version = state_getRuntimeVersion(block_hash)
      spec_name = runtime_version['specName']
      spec_version = runtime_version['specVersion']
      metadata = cached_metadata(spec_name, spec_version, cache_dir)
      return metadata if metadata

      # Get metadata from node
      metadata_hex = state_getMetadata(block_hash)
      metadata = ScaleRb::Metadata.decode_metadata(metadata_hex.strip._to_bytes)

      # cache it
      save_metadata_to_file(spec_name, spec_version, metadata, cache_dir)

      return metadata
    end

    def cached_metadata(spec_name, spec_version, dir)
      file_path = File.join(dir, "#{spec_name}-#{spec_version}.json")
      return unless File.exist?(file_path)

      JSON.parse(File.read(file_path))
    end

    def save_metadata_to_file(spec_name, spec_version, metadata, dir)
      FileUtils.mkdir_p(dir)

      File.open(File.join(dir, "#{spec_name}-#{spec_version}.json"), 'w') do |f|
        f.write(JSON.pretty_generate(metadata))
      end
    end

    ####

    def query_storage_at(block_hash, storage_keys, type_id, default, registry)
      result = state_queryStorageAt(storage_keys, block_hash)
      result.map do |item|
        item['changes'].map do |change|
          storage_key = change[0]
          data = change[1] || default
          storage = data.nil? ? nil : PortableCodec.decode(type_id, data._to_bytes, registry)[0]
          { storage_key: storage_key, storage: storage }
        end
      end.flatten
    end

    def get_storage_keys_by_partial_key(block_hash, partial_storage_key, start_key = nil)
      storage_keys = state_getKeysPaged(partial_storage_key, 1000, start_key, block_hash)
      if storage_keys.length == 1000
        storage_keys + get_storage_keys_by_partial_key(block_hash, partial_storage_key, storage_keys.last)
      else
        storage_keys
      end
    end

    def get_storages_by_partial_key(block_hash, partial_storage_key, type_id_of_value, default, registry)
      storage_keys = get_storage_keys_by_partial_key(block_hash, partial_storage_key, partial_storage_key)
      storage_keys.each_slice(250).map do |slice|
        query_storage_at(
          slice,
          type_id_of_value,
          default,
          registry,
          block_hash
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
    def get_storage1(block_hash, pallet_name, item_name, key, value, registry)
      if key
        if key[:value].nil? || key[:value].empty?
          # map, but no key's value provided. get all storages under the partial storage key
          partial_storage_key = StorageHelper.encode_storage_key(pallet_name, item_name)._to_hex
          get_storages_by_partial_key(
            block_hash,
            partial_storage_key,
            value[:type],
            value[:modifier] == 'Default' ? value[:fallback] : nil,
            registry
          )
        elsif key[:value].length != key[:hashers].length
          # map with multi parts, but not have all values
          partial_storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry)._to_hex
          get_storages_by_partial_key(
            block_hash,
            partial_storage_key,
            value[:type],
            value[:modifier] == 'Default' ? value[:fallback] : nil,
            registry
          )
        end
      else
        storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry)._to_hex
        data = state_getStorage(storage_key, block_hash)
        StorageHelper.decode_storage(data, value[:type], value[:modifier] == 'Optional', value[:fallback], registry)
      end
    end

    def get_storage2(block_hash, pallet_name, item_name, value_of_key, metadata)
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
      get_storage1(block_hash, pallet_name, item_name, key, value, registry)
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
