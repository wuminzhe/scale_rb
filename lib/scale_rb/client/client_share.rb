module ScaleRb
  # This module is used to add extra methods to both the ScaleRb::WsClient ScaleRb::HttpClient
  module ClientShare
    # get decoded metadata at block_hash
    def get_metadata(block_hash = nil)
      block_hash ||= chain_getHead
      metadata_hex = state_getMetadata(block_hash)
      Metadata::Metadata.from_hex(metadata_hex)
    end

    # Get decoded storage at block_hash
    def get_storage(pallet_name, storage_name, params = [], block_hash: nil, metadata: nil)
      block_hash ||= chain_getHead
      metadata ||= get_metadata(block_hash)

      # storeage item
      pallet_name = convert_to_camel_case pallet_name
      storage_name = convert_to_camel_case storage_name

      # storage param
      ScaleRb.logger.debug "#{pallet_name}.#{storage_name}(#{params.inspect})"
      params = params.map { |param| c(param) }

      get_storage2(
        block_hash, # at
        pallet_name,
        storage_name,
        params,
        metadata
      )
    end

    private

    def query_storage_at(block_hash, storage_keys, type_id, default, registry)
      result = state_queryStorageAt(storage_keys, block_hash)
      result.map do |item|
        item[:changes].map do |change|
          storage_key = change[0]
          data = change[1] || default
          storage = data.nil? ? nil : Codec.decode(type_id, Utils.hex_to_u8a(data), registry)[0]
          { storage_key:, storage: }
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
          block_hash,
          slice,
          type_id_of_value,
          default,
          registry
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
    #     value: [[Utils.hex_to_u8a('0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641')]], # [AccountId]
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
    # key is for the param, value is for the return
    def get_storage1(block_hash, pallet_name, item_name, key, value, registry)
      ScaleRb.logger.debug "#{pallet_name}.#{item_name}, key: #{key.inspect}, value: #{value}"

      if key
        if key[:value].nil? || key[:value].empty?
          # map, but no key's value provided. get all storages under the partial storage key
          partial_storage_key = Utils.u8a_to_hex(StorageHelper.encode_storage_key(pallet_name, item_name))
          get_storages_by_partial_key(
            block_hash,
            partial_storage_key,
            value[:type],
            value[:modifier] == 'Default' ? value[:fallback] : nil,
            registry
          )
        elsif key[:value].length != key[:hashers].length
          # map with multi parts, but not have all values
          partial_storage_key = Utils.u8a_to_hex(StorageHelper.encode_storage_key(pallet_name, item_name, key,
                                                                                  registry))
          get_storages_by_partial_key(
            block_hash,
            partial_storage_key,
            value[:type],
            value[:modifier] == 'Default' ? value[:fallback] : nil,
            registry
          )
        else
          storage_key = Utils.u8a_to_hex(StorageHelper.encode_storage_key(pallet_name, item_name, key, registry))
          data = state_getStorage(storage_key, block_hash)
          StorageHelper.decode_storage(data, value[:type], value[:modifier] == 'Optional', value[:fallback], registry)
        end
      else
        storage_key = Utils.u8a_to_hex(StorageHelper.encode_storage_key(pallet_name, item_name))
        data = state_getStorage(storage_key, block_hash)
        StorageHelper.decode_storage(data, value[:type], value[:modifier] == 'Optional', value[:fallback], registry)
      end
    end

    def get_storage2(block_hash, pallet_name, item_name, params, metadata)
      raise 'Metadata should not be nil' if metadata.nil?

      registry = metadata.registry
      item = metadata.storage(pallet_name, item_name)
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
            { type: plain, modifier:, fallback: }
          ]
        elsif map
          [
            { value: params, type: map._get(:key), hashers: map._get(:hashers) },
            { type: map._get(:value), modifier:, fallback: }
          ]
        else
          raise 'NoSuchStorageType'
        end
      get_storage1(block_hash, pallet_name, item_name, key, value, registry)
    end

    def convert_to_camel_case(str)
      words = str.split(/_|(?=[A-Z])/)
      words.map(&:capitalize).join
    end

    # convert key to byte array
    def c(key)
      if key.is_a?(Integer)
        key.to_i
      elsif key.is_a?(String) && key.start_with?('0x')
        Utils.hex_to_u8a(key)
      else
        key
      end
    end
  end
end
