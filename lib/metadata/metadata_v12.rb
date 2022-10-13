# frozen_string_literal: true

module Metadata
  module MetadataV12
    class << self
      def build_registry(metadata)
        types = metadata._get(:lookup)._get(:types)
        types.map { |type| [type._get(:id), type._get(:type)] }.to_h
      end

      def get_storage_item(pallet_name, item_name, metadata)
        pallet =
          metadata._get(:pallets).find do |p|
            p._get(:name) == pallet_name
          end

        pallet._get(:storage)._get(:items).find do |item|
          item._get(:name) == item_name
        end
      end
    end

    TYPES = {
      ErrorMetadataV12: 'ErrorMetadataV11',
      EventMetadataV12: 'EventMetadataV11',
      ExtrinsicMetadataV12: 'ExtrinsicMetadataV11',
      FunctionArgumentMetadataV12: 'FunctionArgumentMetadataV11',
      FunctionMetadataV12: 'FunctionMetadataV11',
      MetadataV12: {
        modules: 'Vec<ModuleMetadataV12>',
        extrinsic: 'ExtrinsicMetadataV12'
      },
      ModuleConstantMetadataV12: 'ModuleConstantMetadataV11',
      ModuleMetadataV12: {
        name: 'Text',
        storage: 'Option<StorageMetadataV12>',
        calls: 'Option<Vec<FunctionMetadataV12>>',
        events: 'Option<Vec<EventMetadataV12>>',
        constants: 'Vec<ModuleConstantMetadataV12>',
        errors: 'Vec<ErrorMetadataV12>',
        index: 'u8'
      },
      StorageEntryModifierV12: 'StorageEntryModifierV11',
      StorageEntryMetadataV12: 'StorageEntryMetadataV11',
      StorageEntryTypeV12: 'StorageEntryTypeV11',
      StorageMetadataV12: 'StorageMetadataV11',
      StorageHasherV12: 'StorageHasherV11'
    }.freeze
  end
end
