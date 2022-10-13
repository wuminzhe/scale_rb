# frozen_string_literal: true

module Metadata
  module MetadataV9
    class << self
      def get_module(module_name, metadata)
        metadata._get(:metadata)._get(:v9)._get(:modules).find do |m|
          m._get(:name) == module_name
        end
      end

      def get_storage_item(module_name, item_name, metadata)
        modula = get_module(module_name, metadata)
        modula._get(:storage)._get(:items).find do |item|
          item._get(:name) == item_name
        end
      end
    end

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
