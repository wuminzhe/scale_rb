# frozen_string_literal: true

module ScaleRb
  module Metadata
    module MetadataV10
      class << self
        def get_module(module_name, metadata)
          metadata._get(:metadata, :v10, :modules).find do |m|
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
        ErrorMetadataV10: 'ErrorMetadataV9',
        EventMetadataV10: 'EventMetadataV9',
        FunctionArgumentMetadataV10: 'FunctionArgumentMetadataV9',
        FunctionMetadataV10: 'FunctionMetadataV9',
        MetadataV10: {
          modules: 'Vec<ModuleMetadataV10>'
        },
        ModuleConstantMetadataV10: 'ModuleConstantMetadataV9',
        ModuleMetadataV10: {
          name: 'Text',
          storage: 'Option<StorageMetadataV10>',
          calls: 'Option<Vec<FunctionMetadataV10>>',
          events: 'Option<Vec<EventMetadataV10>>',
          constants: 'Vec<ModuleConstantMetadataV10>',
          errors: 'Vec<ErrorMetadataV10>'
        },
        StorageEntryModifierV10: 'StorageEntryModifierV9',
        StorageEntryMetadataV10: {
          name: 'Text',
          modifier: 'StorageEntryModifierV10',
          type: 'StorageEntryTypeV10',
          fallback: 'Bytes',
          docs: 'Vec<Text>'
        },
        StorageEntryTypeV10: {
          _enum: {
            Plain: 'Type',
            Map: {
              hasher: 'StorageHasherV10',
              key: 'Type',
              value: 'Type',
              linked: 'bool'
            },
            DoubleMap: {
              hasher: 'StorageHasherV10',
              key1: 'Type',
              key2: 'Type',
              value: 'Type',
              key2Hasher: 'StorageHasherV10'
            }
          }
        },
        StorageMetadataV10: {
          prefix: 'Text',
          items: 'Vec<StorageEntryMetadataV10>'
        },
        StorageHasherV10: {
          _enum: %w[
            Blake2_128
            Blake2_256
            Blake2_128Concat
            Twox128
            Twox256
            Twox64Concat
          ]
        }
      }.freeze
    end
  end
end
