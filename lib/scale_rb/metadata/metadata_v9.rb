# frozen_string_literal: true

module ScaleRb
  module Metadata
    module MetadataV9
      TYPES = {
        ErrorMetadataV9: {
          name: 'Text',
          docs: 'Vec<Text>'
        },
        EventMetadataV9: {
          name: 'Text',
          args: 'Vec<Type>',
          docs: 'Vec<Text>'
        },
        FunctionArgumentMetadataV9: {
          name: 'Text',
          type: 'Type'
        },
        FunctionMetadataV9: {
          name: 'Text',
          args: 'Vec<FunctionArgumentMetadataV9>',
          docs: 'Vec<Text>'
        },
        MetadataV9: {
          modules: 'Vec<ModuleMetadataV9>'
        },
        ModuleConstantMetadataV9: {
          name: 'Text',
          type: 'Type',
          value: 'Bytes',
          docs: 'Vec<Text>'
        },
        ModuleMetadataV9: {
          name: 'Text',
          storage: 'Option<StorageMetadataV9>',
          calls: 'Option<Vec<FunctionMetadataV9>>',
          events: 'Option<Vec<EventMetadataV9>>',
          constants: 'Vec<ModuleConstantMetadataV9>',
          errors: 'Vec<ErrorMetadataV9>'
        },
        StorageEntryMetadataV9: {
          name: 'Text',
          modifier: 'StorageEntryModifierV9',
          type: 'StorageEntryTypeV9',
          fallback: 'Bytes',
          docs: 'Vec<Text>'
        },
        StorageEntryModifierV9: {
          _enum: %w[Optional Default Required]
        },
        StorageEntryTypeV9: {
          _enum: {
            Plain: 'Type',
            Map: {
              hasher: 'StorageHasherV9',
              key: 'Type',
              value: 'Type',
              linked: 'bool'
            },
            DoubleMap: {
              hasher: 'StorageHasherV9',
              key1: 'Type',
              key2: 'Type',
              value: 'Type',
              key2Hasher: 'StorageHasherV9'
            }
          }
        },
        StorageHasherV9: {
          _enum: %w[
            Blake2_128
            Blake2_256
            Twox128
            Twox256
            Twox64Concat
          ]
        },
        StorageMetadataV9: {
          prefix: 'Text',
          items: 'Vec<StorageEntryMetadataV9>'
        }
      }.freeze
    end
  end
end
