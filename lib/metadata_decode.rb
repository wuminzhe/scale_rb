# frozen_string_literal: true

# TODO: build cli tool to decode metadata v14
module ScaleRb2
  METADATA_V14_TYPES = {
    'MagicMetadata' => {
      magicNumber: 'U32',
      metadata: 'Metadata'
    },
    'Metadata' => {
      _enum: {
        V0: 'MetadataV0',
        V1: 'MetadataV1',
        V2: 'MetadataV2',
        V3: 'MetadataV3',
        V4: 'MetadataV4',
        V5: 'MetadataV5',
        V6: 'MetadataV6',
        V7: 'MetadataV7',
        V8: 'MetadataV8',
        V9: 'MetadataV9',
        V10: 'MetadataV10',
        V11: 'MetadataV11',
        V12: 'MetadataV12',
        V13: 'MetadataV13',
        V14: 'MetadataV14'
      }
    },

    'MetadataV14' => {
      lookup: 'PortableRegistry',
      pallets: 'Vec<PalletMetadataV14>',
      extrinsic: 'ExtrinsicMetadataV14',
      type: 'SiLookupTypeId'
    },

    # PortableRegistry begin
    'PortableRegistry' => {
      types: 'Vec<PortableTypeV14>'
    },
    'PortableTypeV14' => {
      id: 'Si1LookupTypeId',
      type: 'Si1Type'
    },
    'Si1LookupTypeId' => 'Compact',
    'Si1Type' => {
      path: 'Si1Path',
      params: 'Vec<Si1TypeParameter>',
      def: 'Si1TypeDef',
      docs: 'Vec<Text>'
    },
    'Si1Path' => 'Vec<Text>',
    'Si1TypeParameter' => {
      name: 'Text',
      type: 'Option<Si1LookupTypeId>'
    },
    'Si1TypeDef' => {
      _enum: {
        Composite: 'Si1TypeDefComposite',
        Variant: 'Si1TypeDefVariant',
        Sequence: 'Si1TypeDefSequence',
        Array: 'Si1TypeDefArray',
        Tuple: 'Si1TypeDefTuple',
        Primitive: 'Si1TypeDefPrimitive',
        Compact: 'Si1TypeDefCompact',
        BitSequence: 'Si1TypeDefBitSequence',
        HistoricMetaCompat: 'Text' # TODO: sanitize?
      }
    },
    'Si1TypeDefComposite' => {
      fields: 'Vec<Si1Field>'
    },
    'Si1Field' => {
      name: 'Option<Text>',
      type: 'Si1LookupTypeId',
      typeName: 'Option<Text>',
      docs: 'Vec<Text>'
    },
    'Si1TypeDefVariant' => {
      variants: 'Vec<Si1Variant>'
    },
    'Si1Variant' => {
      name: 'Text',
      fields: 'Vec<Si1Field>',
      index: 'u8',
      docs: 'Vec<Text>'
    },
    'Si1TypeDefSequence' => {
      type: 'Si1LookupTypeId'
    },
    'Si1TypeDefArray' => {
      len: 'u32',
      type: 'Si1LookupTypeId'
    },
    'Si1TypeDefTuple' => 'Vec<Si1LookupTypeId>',
    'Si1TypeDefPrimitive' => {
      _enum: %w[
        Bool Char Str U8 U16 U32 U64 U128 U256 I8 I16 I32 I64 I128 I256
      ]
    },
    'Si1TypeDefCompact' => {
      type: 'Si1LookupTypeId'
    },
    'Si1TypeDefBitSequence' => {
      bitStoreType: 'Si1LookupTypeId',
      bitOrderType: 'Si1LookupTypeId'
    },
    # PortableRegistry end

    # PalletMetadataV14 begin
    'PalletMetadataV14' => {
      name: 'Text',
      storage: 'Option<PalletStorageMetadataV14>',
      calls: 'Option<PalletCallMetadataV14>',
      events: 'Option<PalletEventMetadataV14>',
      constants: 'Vec<PalletConstantMetadataV14>',
      errors: 'Option<PalletErrorMetadataV14>',
      index: 'U8'
    },
    'PalletStorageMetadataV14' => {
      prefix: 'Text',
      items: 'Vec<StorageEntryMetadataV14>'
    },
    'StorageEntryMetadataV14' => {
      name: 'Text',
      modifier: 'StorageEntryModifierV14',
      type: 'StorageEntryTypeV14',
      fallback: 'Bytes',
      docs: 'Vec<Text>'
    },
    'StorageEntryModifierV14' => {
      _enum: %w[Optional Default Required]
    },
    'StorageEntryTypeV14' => {
      _enum: {
        Plain: 'SiLookupTypeId',
        Map: {
          hashers: 'Vec<StorageHasherV14>',
          key: 'SiLookupTypeId',
          value: 'SiLookupTypeId'
        }
      }
    },
    'StorageHasherV14' => {
      _enum: %w[Blake2128 Blake2256 Blake2128Concat Twox128 Twox256 Twox64Concat Identity]
    },
    'PalletCallMetadataV14' => {
      type: 'Si1LookupTypeId'
    },
    'PalletEventMetadataV14' => {
      type: 'SiLookupTypeId'
    },
    'PalletConstantMetadataV14' => {
      name: 'Text',
      type: 'SiLookupTypeId',
      value: 'Bytes',
      docs: 'Vec<Text>'
    },
    'PalletErrorMetadataV14' => {
      type: 'SiLookupTypeId'
    },
    # PalletMetadataV14 end

    # ExtrinsicMetadataV14 begin
    'ExtrinsicMetadataV14' => {
      type: 'SiLookupTypeId',
      version: 'u8',
      signedExtensions: 'Vec<SignedExtensionMetadataV14>'
    },
    'SignedExtensionMetadataV14' => {
      identifier: 'Text',
      type: 'SiLookupTypeId',
      additionalSigned: 'SiLookupTypeId'
    },
    # ExtrinsicMetadataV14 end

    'SiLookupTypeId' => 'Compact'
  }.freeze

  def self.decode_metadata(bytes)
    metadata, = ScaleRb2.decode('MagicMetadata', bytes, METADATA_V14_TYPES)
    metadata
  end
end
