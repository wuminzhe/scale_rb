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

    def get_storage_item(pallet_name, item_name, metadata)
      version = metadata._get(:metadata).keys.first
      raise ScaleRb::NotImplemented, metadata._get(:metadata).keys.first unless %w[v9 v10 v11 v12 v13 v14].include?(version.to_s)

      Metadata.const_get("Metadata#{version.upcase}").get_storage_item(pallet_name, item_name, metadata)
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
