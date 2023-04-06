# frozen_string_literal: true

module Metadata
  class << self
    def decode_metadata(bytes)
      metadata, = ScaleRb.decode('MetadataTop', bytes, TYPES)
      metadata
    end

    def build_registry(metadata)
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless metadata._get(:metadata)._key?(:v14)

      metadata_v14 = metadata._get(:metadata)._get(:v14)
      MetadataV14.build_registry(metadata_v14)
    end

    def get_module(pallet_name, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_module(pallet_name, metadata)
    end

    def get_module_by_index(pallet_index, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_module_by_index(pallet_index, metadata)
    end

    def get_storage_item(pallet_name, item_name, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_storage_item(pallet_name, item_name, metadata)
    end

    def get_calls_type(pallet_name, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_calls_type(pallet_name, metadata)
    end

    def get_calls_type_id(pallet_name, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_calls_type_id(pallet_name, metadata)
    end

    def get_call_type(pallet_name, call_name, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_call_type(pallet_name, call_name, metadata) 
    end

    # call examples:
    #   {:pallet_name=>"Deposit", :call_name=>"Claim", :call=>["claim", []]}
    #   {:pallet_name=>"Balances", :call_name=>"Transfer", :call=>[{:transfer=>{:dest=>[10, 18, 135, 151, 117, 120, 248, 136, 189, 193, 199, 98, 119, 129, 175, 28, 192, 0, 230, 171], :value=>11000000000000000000}}, []]}
    def encode_call(call, metadata)
      calls_type_id = get_calls_type_id(call[:pallet_name], metadata)
      pallet_index = get_module(call[:pallet_name], metadata)._get(:index)
      [pallet_index] + PortableCodec.encode(calls_type_id, call[:call].first, build_registry(metadata))
    end

    # callbytes's structure is: pallet_index + call_index + argsbytes
    # 
    # callbytes examples:
    #   "0x0901".to_bytes
    #   "0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798".to_bytes
    def decode_call(callbytes, metadata)
      pallet_index = callbytes[0]
      pallet = get_module_by_index(pallet_index, metadata)
      
      pallet_name = pallet._get(:name)

      # Remove the pallet_index
      # The callbytes we used below should not contain the pallet index. 
      # This is because the pallet index is not part of the call type.
      # Its structure is: call_index + call_args
      callbytes_without_pallet_index = callbytes[1..]
      calls_type_id = pallet._get(:calls)._get(:type)
      decoded = PortableCodec.decode(
        calls_type_id, 
        callbytes_without_pallet_index, 
        build_registry(metadata)
      )

      {
        pallet_name: pallet_name,
        call_name: decoded.first.is_a?(String) ? decoded.first.to_camel : decoded.first.keys.first.to_s.to_camel,
        call: decoded
      }
    end
  end

  TYPES = {
    'MetadataTop' => {
      magicNumber: 'U32',
      metadata: 'Metadata'
    },
    'Metadata' => {
      _enum: {
        v0: 'MetadataV0',
        v1: 'MetadataV1',
        v2: 'MetadataV2',
        v3: 'MetadataV3',
        v4: 'MetadataV4',
        v5: 'MetadataV5',
        v6: 'MetadataV6',
        v7: 'MetadataV7',
        v8: 'MetadataV8',
        v9: 'MetadataV9',
        v10: 'MetadataV10',
        v11: 'MetadataV11',
        v12: 'MetadataV12',
        v13: 'MetadataV13',
        v14: 'MetadataV14'
      }
    }
  }.merge(MetadataV14::TYPES)
          .merge(MetadataV13::TYPES)
          .merge(MetadataV12::TYPES)
          .merge(MetadataV11::TYPES)
          .merge(MetadataV10::TYPES)
          .merge(MetadataV9::TYPES)
end
