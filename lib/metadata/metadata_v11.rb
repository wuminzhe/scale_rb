# frozen_string_literal: true

module ScaleRb
  module Metadata
    module MetadataV11
      class << self
        def get_module(module_name, metadata)
          metadata._get(:metadata, :v11, :modules).find do |m|
            m._get(:name) == module_name
          end
        end

        def get_storage_item(module_name, item_name, metadata)
          modula = get_module(module_name, metadata)
          raise "Module `#{module_name}` not found" if modula.nil?

          modula._get(:storage, :items).find do |item|
            item._get(:name) == item_name
          end
        end
      end

      TYPES = {
        ErrorMetadataV11: 'ErrorMetadataV10',
        EventMetadataV11: 'EventMetadataV10',
        ExtrinsicMetadataV11: {
          version: 'u8',
          signedExtensions: 'Vec<Text>'
        },
        FunctionArgumentMetadataV11: 'FunctionArgumentMetadataV10',
        FunctionMetadataV11: 'FunctionMetadataV10',
        MetadataV11: {
          modules: 'Vec<ModuleMetadataV11>',
          extrinsic: 'ExtrinsicMetadataV11'
        },
        ModuleConstantMetadataV11: 'ModuleConstantMetadataV10',
        ModuleMetadataV11: {
          name: 'Text',
          storage: 'Option<StorageMetadataV11>',
          calls: 'Option<Vec<FunctionMetadataV11>>',
          events: 'Option<Vec<EventMetadataV11>>',
          constants: 'Vec<ModuleConstantMetadataV11>',
          errors: 'Vec<ErrorMetadataV11>'
        },
        StorageEntryModifierV11: 'StorageEntryModifierV10',
        StorageEntryMetadataV11: {
          name: 'Text',
          modifier: 'StorageEntryModifierV11',
          type: 'StorageEntryTypeV11',
          fallback: 'Bytes',
          docs: 'Vec<Text>'
        },
        StorageEntryTypeV11: {
          _enum: {
            Plain: 'Type',
            Map: {
              hasher: 'StorageHasherV11',
              key: 'Type',
              value: 'Type',
              linked: 'bool'
            },
            DoubleMap: {
              hasher: 'StorageHasherV11',
              key1: 'Type',
              key2: 'Type',
              value: 'Type',
              key2Hasher: 'StorageHasherV11'
            }
          }
        },
        StorageMetadataV11: {
          prefix: 'Text',
          items: 'Vec<StorageEntryMetadataV11>'
        },
        StorageHasherV11: {
          _enum: %w[
            Blake2_128
            Blake2_256
            Blake2_128Concat
            Twox128
            Twox256
            Twox64Concat
            Identity
          ]
        }
      }.freeze
    end
  end
end
