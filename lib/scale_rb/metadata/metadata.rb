# frozen_string_literal: true

require_relative './registry'

require_relative './metadata_v9'
require_relative './metadata_v10'
require_relative './metadata_v11'
require_relative './metadata_v12'
require_relative './metadata_v13'
require_relative './metadata_v14'

# NOTE: Only v14 and later are supported.
# https://github.com/paritytech/frame-metadata/blob/main/frame-metadata/src/lib.rs#L85
module ScaleRb
  module Metadata
    class << self
      def decode_metadata(hex)
        bytes = ScaleRb::Utils.hex_to_u8a(hex)

        registry = ScaleRb::Metadata::Registry.new TYPES
        ti = registry.use('MetadataPrefixed')
        metadata, = ScaleRb::Codec.decode(ti, bytes, registry)
        metadata
      end

      def build_registry(metadata_prefixed)
        types = ScaleRb::Utils.get(metadata_prefixed, :metadata, :V14, :lookup, :types)
        ScaleRb::PortableRegistry.new(types)
      end

      def get_module(pallet_name, metadata_prefixed)
        metadata = Utils.get(metadata_prefixed, :metadata)
        version = metadata.keys.first
        raise NotImplementedError, version unless %i[V14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_module(pallet_name, metadata_prefixed)
      end

      def get_module_by_index(pallet_index, metadata_prefixed)
        metadata = Utils.get(metadata_prefixed, :metadata)
        version = metadata.keys.first.to_sym
        raise NotImplementedError, version unless %i[V14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_module_by_index(pallet_index, metadata_prefixed)
      end

      def get_storage_item(pallet_name, item_name, metadata_prefixed)
        metadata = Utils.get(metadata_prefixed, :metadata)
        version = metadata.keys.first.to_sym
        raise NotImplementedError, version unless %i[V14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_storage_item(pallet_name, item_name, metadata_prefixed)
      end

      def get_calls_type(pallet_name, metadata_prefixed)
        metadata = Utils.get(metadata_prefixed, :metadata)
        version = metadata.keys.first.to_sym
        raise NotImplementedError, version unless %i[V14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_calls_type(pallet_name, metadata_prefixed)
      end

      def get_calls_type_id(pallet_name, metadata_prefixed)
        metadata = Utils.get(metadata_prefixed, :metadata)
        version = metadata.keys.first.to_sym
        raise NotImplementedError, version unless %i[V14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_calls_type_id(pallet_name, metadata_prefixed)
      end

      def get_call_type(pallet_name, call_name, metadata_prefixed)
        metadata = Utils.get(metadata_prefixed, :metadata)
        version = metadata.keys.first.to_sym
        raise NotImplementedError, version unless %i[V14].include?(version)

        Metadata.const_get("Metadata#{version.upcase}").get_call_type(pallet_name, call_name, metadata_prefixed)
      end
    end

    TYPES = {
      Type: 'Str',
      Bytes: 'Vec<u8>',
      MetadataPrefixed: {
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
