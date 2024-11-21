# frozen_string_literal: true

module ScaleRb
  module Metadata
    module MetadataV14
      class << self
        def build_registry(metadata_prefixed)
          types = ScaleRb::Utils.get(metadata_prefixed, :metadata, :V14, :lookup, :types)
          ScaleRb::PortableRegistry.new(types)
        end

        def get_module(pallet_name, metadata_prefixed)
          metadata_prefixed._get(:metadata, :V14, :pallets).find do |p|
            p._get(:name) == pallet_name
          end
        end

        def get_module_by_index(pallet_index, metadata_prefixed)
          metadata_prefixed._get(:metadata, :V14, :pallets).find do |p|
            p._get(:index) == pallet_index
          end
        end

        def get_storage_item(pallet_name, item_name, metadata_prefixed)
          pallet = get_module(pallet_name, metadata_prefixed)
          raise "Pallet `#{pallet_name}` not found" if pallet.nil?

          pallet._get(:storage, :items).find do |item|
            item._get(:name) == item_name
          end
        end

        def get_calls_type_id(pallet_name, metadata_prefixed)
          pallet = get_module(pallet_name, metadata_prefixed)
          raise "Pallet `#{pallet_name}` not found" if pallet.nil?

          pallet._get(:calls, :type)
        end

        def get_calls_type(pallet_name, metadata_prefixed)
          type_id = get_calls_type_id(pallet_name, metadata_prefixed)
          metadata_prefixed._get(:metadata, :V14, :lookup, :types).find do |type|
            type._get(:id) == type_id
          end
        end

        def get_call_type(pallet_name, call_name, metadata_prefixed)
          calls_type = get_calls_type(pallet_name, metadata_prefixed)
          calls_type._get(:type, :def, :variant, :variants).find do |variant|
            variant._get(:name).downcase == call_name.downcase
          end
        end

        def signature_type(metadata_prefixed); end

        def signed_extensions(metadata_prefixed)
          ScaleRb::Utils.get(metadata_prefixed, :metadata, :V14, :extrinsic, :signedExtensions)
        end
      end

      TYPES = {
        'MetadataV14' => {
          'lookup' => 'PortableRegistry',
          'pallets' => 'Vec<PalletMetadataV14>',
          'extrinsic' => 'ExtrinsicMetadataV14',
          'type' => 'SiLookupTypeId'
        },

        # PortableRegistry begin
        'PortableRegistry' => {
          'types' => 'Vec<PortableTypeV14>'
        },
        'PortableTypeV14' => {
          'id' => 'Si1LookupTypeId',
          'type' => 'Si1Type'
        },
        'Si1LookupTypeId' => 'Compact',
        'Si1Type' => {
          'path' => 'Si1Path',
          'params' => 'Vec<Si1TypeParameter>',
          'def' => 'Si1TypeDef',
          'docs' => 'Vec<Text>'
        },
        'Si1Path' => 'Vec<Text>',
        'Si1TypeParameter' => {
          'name' => 'Text',
          'type' => 'Option<Si1LookupTypeId>'
        },
        'Si1TypeDef' => {
          '_enum' => {
            'composite' => 'Si1TypeDefComposite',
            'variant' => 'Si1TypeDefVariant',
            'sequence' => 'Si1TypeDefSequence',
            'array' => 'Si1TypeDefArray',
            'tuple' => 'Si1TypeDefTuple',
            'primitive' => 'Si1TypeDefPrimitive',
            'compact' => 'Si1TypeDefCompact',
            'bitSequence' => 'Si1TypeDefBitSequence',
            'historicMetaCompat' => 'Text'
          }
        },
        'Si1TypeDefComposite' => {
          'fields' => 'Vec<Si1Field>'
        },
        'Si1Field' => {
          'name' => 'Option<Text>',
          'type' => 'Si1LookupTypeId',
          'typeName' => 'Option<Text>',
          'docs' => 'Vec<Text>'
        },
        'Si1TypeDefVariant' => {
          'variants' => 'Vec<Si1Variant>'
        },
        'Si1Variant' => {
          'name' => 'Text',
          'fields' => 'Vec<Si1Field>',
          'index' => 'u8',
          'docs' => 'Vec<Text>'
        },
        'Si1TypeDefSequence' => {
          'type' => 'Si1LookupTypeId'
        },
        'Si1TypeDefArray' => {
          'len' => 'u32',
          'type' => 'Si1LookupTypeId'
        },
        'Si1TypeDefTuple' => 'Vec<Si1LookupTypeId>',
        'Si1TypeDefPrimitive' => {
          '_enum' => %w[
            Bool Char Str U8 U16 U32 U64 U128 U256 I8 I16 I32 I64 I128 I256
          ]
        },
        'Si1TypeDefCompact' => {
          'type' => 'Si1LookupTypeId'
        },
        'Si1TypeDefBitSequence' => {
          'bitStoreType' => 'Si1LookupTypeId',
          'bitOrderType' => 'Si1LookupTypeId'
        },
        # PortableRegistry end

        # PalletMetadataV14 begin
        'PalletMetadataV14' => {
          'name' => 'Text',
          'storage' => 'Option<PalletStorageMetadataV14>',
          'calls' => 'Option<PalletCallMetadataV14>',
          'events' => 'Option<PalletEventMetadataV14>',
          'constants' => 'Vec<PalletConstantMetadataV14>',
          'errors' => 'Option<PalletErrorMetadataV14>',
          'index' => 'U8'
        },
        'PalletStorageMetadataV14' => {
          'prefix' => 'Text',
          'items' => 'Vec<StorageEntryMetadataV14>'
        },
        'StorageEntryMetadataV14' => {
          'name' => 'Text',
          'modifier' => 'StorageEntryModifierV14',
          'type' => 'StorageEntryTypeV14',
          'fallback' => 'Bytes',
          'docs' => 'Vec<Text>'
        },
        'StorageEntryModifierV14' => {
          '_enum' => %w[Optional Default Required]
        },
        'StorageEntryTypeV14' => {
          '_enum' => {
            'plain' => 'SiLookupTypeId',
            'map' => {
              'hashers' => 'Vec<StorageHasherV14>',
              'key' => 'SiLookupTypeId',
              'value' => 'SiLookupTypeId'
            }
          }
        },
        'StorageHasherV14' => {
          '_enum' => %w[Blake2128 Blake2256 Blake2128Concat Twox128 Twox256 Twox64Concat Identity]
        },
        'PalletCallMetadataV14' => {
          'type' => 'Si1LookupTypeId'
        },
        'PalletEventMetadataV14' => {
          'type' => 'SiLookupTypeId'
        },
        'PalletConstantMetadataV14' => {
          'name' => 'Text',
          'type' => 'SiLookupTypeId',
          'value' => 'Bytes',
          'docs' => 'Vec<Text>'
        },
        'PalletErrorMetadataV14' => {
          'type' => 'SiLookupTypeId'
        },
        # PalletMetadataV14 end

        # ExtrinsicMetadataV14 begin
        'ExtrinsicMetadataV14' => {
          'type' => 'SiLookupTypeId',
          'version' => 'u8',
          'signedExtensions' => 'Vec<SignedExtensionMetadataV14>'
        },
        'SignedExtensionMetadataV14' => {
          'identifier' => 'Text',
          'type' => 'SiLookupTypeId',
          'additionalSigned' => 'SiLookupTypeId'
        },
        # ExtrinsicMetadataV14 end

        'SiLookupTypeId' => 'Compact'
      }.freeze
    end
  end
end
