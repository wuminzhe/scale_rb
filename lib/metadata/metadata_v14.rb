# frozen_string_literal: true

module Metadata
  module MetadataV14
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
      MetadataV14: {
        lookup: 'PortableRegistry',
        pallets: 'Vec<PalletMetadataV14>',
        extrinsic: 'ExtrinsicMetadataV14',
        type: 'SiLookupTypeId'
      },

      # PortableRegistry begin
      PortableRegistry: {
        types: 'Vec<PortableTypeV14>'
      },
      PortableTypeV14: {
        id: 'Si1LookupTypeId',
        type: 'Si1Type'
      },
      Si1LookupTypeId: 'Compact',
      Si1Type: {
        path: 'Si1Path',
        params: 'Vec<Si1TypeParameter>',
        def: 'Si1TypeDef',
        docs: 'Vec<Text>'
      },
      Si1Path: 'Vec<Text>',
      Si1TypeParameter: {
        name: 'Text',
        type: 'Option<Si1LookupTypeId>'
      },
      Si1TypeDef: {
        _enum: {
          composite: 'Si1TypeDefComposite',
          variant: 'Si1TypeDefVariant',
          sequence: 'Si1TypeDefSequence',
          array: 'Si1TypeDefArray',
          tuple: 'Si1TypeDefTuple',
          primitive: 'Si1TypeDefPrimitive',
          compact: 'Si1TypeDefCompact',
          bitSequence: 'Si1TypeDefBitSequence',
          historicMetaCompat: 'Text' # TODO: sanitize?
        }
      },
      Si1TypeDefComposite: {
        fields: 'Vec<Si1Field>'
      },
      Si1Field: {
        name: 'Option<Text>',
        type: 'Si1LookupTypeId',
        typeName: 'Option<Text>',
        docs: 'Vec<Text>'
      },
      Si1TypeDefVariant: {
        variants: 'Vec<Si1Variant>'
      },
      Si1Variant: {
        name: 'Text',
        fields: 'Vec<Si1Field>',
        index: 'u8',
        docs: 'Vec<Text>'
      },
      Si1TypeDefSequence: {
        type: 'Si1LookupTypeId'
      },
      Si1TypeDefArray: {
        len: 'u32',
        type: 'Si1LookupTypeId'
      },
      Si1TypeDefTuple: 'Vec<Si1LookupTypeId>',
      Si1TypeDefPrimitive: {
        _enum: %w[
          Bool Char Str U8 U16 U32 U64 U128 U256 I8 I16 I32 I64 I128 I256
        ]
      },
      Si1TypeDefCompact: {
        type: 'Si1LookupTypeId'
      },
      Si1TypeDefBitSequence: {
        bitStoreType: 'Si1LookupTypeId',
        bitOrderType: 'Si1LookupTypeId'
      },
      # PortableRegistry end

      # PalletMetadataV14 begin
      PalletMetadataV14: {
        name: 'Text',
        storage: 'Option<PalletStorageMetadataV14>',
        calls: 'Option<PalletCallMetadataV14>',
        events: 'Option<PalletEventMetadataV14>',
        constants: 'Vec<PalletConstantMetadataV14>',
        errors: 'Option<PalletErrorMetadataV14>',
        index: 'U8'
      },
      PalletStorageMetadataV14: {
        prefix: 'Text',
        items: 'Vec<StorageEntryMetadataV14>'
      },
      StorageEntryMetadataV14: {
        name: 'Text',
        modifier: 'StorageEntryModifierV14',
        type: 'StorageEntryTypeV14',
        fallback: 'Bytes',
        docs: 'Vec<Text>'
      },
      StorageEntryModifierV14: {
        _enum: %w[Optional Default Required]
      },
      StorageEntryTypeV14: {
        _enum: {
          plain: 'SiLookupTypeId',
          map: {
            hashers: 'Vec<StorageHasherV14>',
            key: 'SiLookupTypeId',
            value: 'SiLookupTypeId'
          }
        }
      },
      StorageHasherV14: {
        _enum: %w[Blake2128 Blake2256 Blake2128Concat Twox128 Twox256 Twox64Concat Identity]
      },
      PalletCallMetadataV14: {
        type: 'Si1LookupTypeId'
      },
      PalletEventMetadataV14: {
        type: 'SiLookupTypeId'
      },
      PalletConstantMetadataV14: {
        name: 'Text',
        type: 'SiLookupTypeId',
        value: 'Bytes',
        docs: 'Vec<Text>'
      },
      PalletErrorMetadataV14: {
        type: 'SiLookupTypeId'
      },
      # PalletMetadataV14 end

      # ExtrinsicMetadataV14 begin
      ExtrinsicMetadataV14: {
        type: 'SiLookupTypeId',
        version: 'u8',
        signedExtensions: 'Vec<SignedExtensionMetadataV14>'
      },
      SignedExtensionMetadataV14: {
        identifier: 'Text',
        type: 'SiLookupTypeId',
        additionalSigned: 'SiLookupTypeId'
      },
      # ExtrinsicMetadataV14 end

      SiLookupTypeId: 'Compact'
    }.freeze
  end
end
