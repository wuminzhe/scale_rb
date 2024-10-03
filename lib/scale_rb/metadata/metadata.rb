# frozen_string_literal: true

require_relative './registry'

require_relative './metadata_v9'
require_relative './metadata_v10'
require_relative './metadata_v11'
require_relative './metadata_v12'
require_relative './metadata_v13'
require_relative './metadata_v14'

module ScaleRb
  module Metadata
    class << self
      def decode_metadata(hex)
        bytes = ScaleRb::Utils.hex_to_u8a(hex)

        registry = ScaleRb::Metadata::Registry.new TYPES
        ti = registry.use('MetadataTop')
        metadata, = ScaleRb::Codec.decode(ti, bytes, registry)
        metadata
      end

      def build_registry(metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless Utils.key?(metadata, :v14)

        metadata_v14 = Utils.get(metadata, :v14)
        MetadataV14.build_registry(metadata_v14)
      end

      def get_module(pallet_name, metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless %w[v9 v10 v11 v12 v13 v14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_module(pallet_name, metadata_top)
      end

      def get_module_by_index(pallet_index, metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless %w[v9 v10 v11 v12 v13 v14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_module_by_index(pallet_index, metadata_top)
      end

      def get_storage_item(pallet_name, item_name, metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless %w[v9 v10 v11 v12 v13 v14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_storage_item(pallet_name, item_name, metadata_top)
      end

      def get_calls_type(pallet_name, metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless %w[v9 v10 v11 v12 v13 v14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_calls_type(pallet_name, metadata_top)
      end

      def get_calls_type_id(pallet_name, metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless %w[v9 v10 v11 v12 v13 v14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_calls_type_id(pallet_name, metadata_top)
      end

      def get_call_type(pallet_name, call_name, metadata_top)
        metadata = Utils.get(metadata_top, :metadata)
        version = metadata.keys.first.to_s
        raise ScaleRb::NotImplemented, version unless %w[v9 v10 v11 v12 v13 v14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_call_type(pallet_name, call_name, metadata_top)
      end

      # call examples:
      #   {:pallet_name=>"Deposit", :call_name=>"Claim", :call=>["claim", []]}
      #   {:pallet_name=>"Balances", :call_name=>"Transfer", :call=>[{:transfer=>{:dest=>[10, 18, 135, 151, 117, 120, 248, 136, 189, 193, 199, 98, 119, 129, 175, 28, 192, 0, 230, 171], :value=>11000000000000000000}}, []]}
      def encode_call(call, metadata)
        calls_type_id = get_calls_type_id(call[:pallet_name], metadata)
        pallet_index = Utils.get(get_module(call[:pallet_name], metadata), :index)
        [pallet_index] + PortableCodec.encode(calls_type_id, call[:call].first, build_registry(metadata))
      end

      # callbytes's structure is: pallet_index + call_index + argsbytes
      #
      # callbytes examples:
      #   "0x0901"
      #   "0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798"
      def decode_call(callbytes, metadata)
        callbytes = Utils.hex_to_u8a(callbytes) if callbytes.is_a?(::String)

        pallet_index = callbytes[0]
        pallet = get_module_by_index(pallet_index, metadata)

        pallet_name = Utils.get(pallet, :name)

        # Remove the pallet_index
        # The callbytes we used below should not contain the pallet index.
        # This is because the pallet index is not part of the call type.
        # Its structure is: call_index + call_args
        callbytes_without_pallet_index = callbytes[1..]
        calls_type_id = Utils.get(pallet, :calls, :type)
        decoded = PortableCodec.decode(
          calls_type_id,
          callbytes_without_pallet_index,
          build_registry(metadata)
        )

        {
          pallet_name:,
          call_name: decoded.first.is_a?(String) ? Utils.camelize(decoded.first) : Utils.camelize(decoded.first.keys.first.to_s),
          call: decoded
        }
      end
    end

    TYPES = {
      Type: 'Str',
      Bytes: 'Vec<u8>',
      MetadataTop: {
        magicNumber: 'U32',
        metadata: 'Metadata'
      },
      Placeholder: 'Null',
      Metadata: {
        _enum: {
          V0: 'Placeholder',
          V1: 'Placeholder',
          V2: 'Placeholder',
          V3: 'Placeholder',
          V4: 'Placeholder',
          V5: 'Placeholder',
          V6: 'Placeholder',
          V7: 'Placeholder',
          V8: 'Placeholder',
          V9: 'MetadataV9',
          V10: 'MetadataV10',
          V11: 'MetadataV11',
          V12: 'MetadataV12',
          V13: 'MetadataV13',
          V14: 'MetadataV14'
        }
      }
    }.merge(MetadataV14::TYPES)
            .merge(MetadataV13::TYPES)
            .merge(MetadataV12::TYPES)
            .merge(MetadataV11::TYPES)
            .merge(MetadataV10::TYPES)
            .merge(MetadataV9::TYPES)
  end
end
