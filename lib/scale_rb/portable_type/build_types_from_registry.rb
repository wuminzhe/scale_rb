# frozen_string_literal: true

class TypeAlias
  # % alias :: Ti
  attr_reader :alias

  # % name :: String
  attr_reader :name

  # % initialize :: String -> Ti -> void
  def initialize(name, the_alias)
    @name = name
    @alias = the_alias
  end

  def to_s
    @alias
  end
end

module ScaleRb
  # % build_types_from_registry :: Hash<Symbol, Any> -> Array<PortableType>
  # data exmaple: {
  #   MetadataTop: {
  #     magicNumber: 'U32',
  #     metadata: 'Metadata'
  #   },
  #   Metadata: {
  #     _enum: {
  #       v13: 'MetadataV13',
  #       v14: 'MetadataV14'
  #     }
  #   },
  #   MetadataV13: {
  #     modules: 'Vec<ModuleMetadataV13>',
  #     extrinsic: 'ExtrinsicMetadataV13'
  #   },
  #   ModuleMetadataV13: {
  #     name: 'Text',
  #     storage: 'Option<StorageMetadataV13>',
  #     calls: 'Option<Vec<FunctionMetadataV13>>',
  #     events: 'Option<Vec<EventMetadataV13>>',
  #     constants: 'Vec<ModuleConstantMetadataV13>',
  #     errors: 'Vec<ErrorMetadataV13>',
  #     index: 'u8'
  #   },
  #   StorageMetadataV13: {
  #     prefix: 'Text',
  #     items: 'Vec<StorageEntryMetadataV13>'
  #   },
  #   StorageEntryMetadataV13: {
  #     name: 'Text',
  #     modifier: 'StorageEntryModifierV13',
  #     type: 'StorageEntryTypeV13',
  #     fallback: 'Bytes',
  #     docs: 'Vec<Text>'
  #   },
  #   StorageEntryModifierV13: 'StorageEntryModifierV12',
  #   StorageEntryTypeV13: {
  #     _enum: {
  #       plain: 'Type',
  #       map: {
  #         hasher: 'StorageHasherV13',
  #         key: 'Type',
  #         value: 'Type',
  #         linked: 'bool'
  #       },
  #       doubleMap: {
  #         hasher: 'StorageHasherV13',
  #         key1: 'Type',
  #         key2: 'Type',
  #         value: 'Type',
  #         key2Hasher: 'StorageHasherV13'
  #       },
  #       nMap: {
  #         keyVec: 'Vec<Type>',
  #         hashers: 'Vec<StorageHasherV13>',
  #         value: 'Type'
  #       }
  #     }
  #   },
  #   StorageHasherV13: 'StorageHasherV12',
  #   FunctionMetadataV13: 'FunctionMetadataV12',
  #   EventMetadataV13: 'EventMetadataV12',
  #   ModuleConstantMetadataV13: 'ModuleConstantMetadataV12',
  #   ErrorMetadataV13: 'ErrorMetadataV12',
  #   ExtrinsicMetadataV13: 'ExtrinsicMetadataV12'
  # }
  def build_types_from_registry(data); end

  # heavily inspired by https://github.com/paritytech/subsquid/blob/main/sdk/types/lib/types/build_types_from_registry.rs
  class ToTypes
    # Map name to index of type in `types` array
    # % lookup :: String -> Integer
    attr_reader :lookup

    # % types :: Array<PortableType>
    attr_reader :types

    # % initialize :: Hash<Symbol, Any> -> void
    def initialize(old_types)
      @old_types = old_types
      @lookup = {}
    end

    # % use :: String -> Integer
    def use(old_type_exp)
      ast_type = TypeExp.parse(old_type_exp)
      key = ast_type.to_s
      ti = lookup[key]
      return ti if ti

      ti = @types.length
      lookup[key] = ti
      @types << build_portable_type(ast_type)
      ti
    end

    # % build_portable_type :: NamedType | ArrayType | TupleType -> PortableType
    def build_portable_type(ast_type)
      case ast_type
      when ArrayType
        ScaleRb::ArrayType.new(use(ast_type.item), ast_type.len)
      when TupleType
        ScaleRb::TupleType.new(ast_type.params.map { |param| use(param) })
      when NamedType
        build_portable_type_from_named_type(ast_type)
      end
    end

    # % build_portable_type_from_named_type :: NamedType -> PortableType
    def build_portable_type_from_named_type(named_type)
      name = named_type.name
      params = named_type.params

      definition = @old_types[name]
      return build_from_definition(name, definition) if definition

      primitive = as_primitive(name)
      return primitive if primitive

      case name
      when 'Vec'
        item_index = use(params[0].to_s)
        SequenceType.new(item_index)
      when 'Option'
        item_index = use(params[0].to_s)
        VariantType.option(item_index)
      when 'Result'
        ok_index = use(params[0].to_s)
        err_index = use(params[1].to_s)
        VariantType.result(ok_index, err_index)
      when 'Compact'
        item_index = use(params[0].to_s)
        CompactType.new(item_index)
      else
        raise "Unknown type: #{name}"
      end
    end

    # % as_primitive :: String -> PrimitiveType | nil
    def as_primitive(name)
      case name.downcase
      when /^i\d+$/
        PrimitiveType.new("I#{name[1..]}")
      when /^u\d+$/
        PrimitiveType.new("U#{name[1..]}")
      when /^bool$/
        PrimitiveType.new('Bool')
      when /^str$/, /^text$/
        PrimitiveType.new('Str')
      end
    end

    # % build_from_definition :: String -> OldTypeDefinition -> PortableType | TypeAlias
    #
    # type OldTypeDefinition = String | OldEnumDefinition | OldStructDefinition
    # type OldEnumDefinition = {
    #   _enum: String[] | Hash<Symbol, Any>,
    # }
    # type OldStructDefinition = {
    #   _struct: Hash<Symbol, Any>
    # }
    def build_from_definition(name, definition) # rubocop:disable Metrics/MethodLength
      case definition
      when String
        TypeAlias.new(name, use(definition))
      when Hash
        if definition[:_enum]
          _build_portable_type_from_enum_definition(definition)
        elsif definition[:_set]
          raise 'Sets are not supported'
        else
          _build_portable_type_from_struct_definition(definition)
        end
      end
    end

    private

    def _indexed_enum?(definition)
      definition[:_enum].is_a?(Hash) && definition[:_enum].values.all? { |value| value.is_a?(Integer) }
    end

    # % _build_portable_type_from_enum_definition :: Hash<Symbol, Any> -> VariantType
    def _build_portable_type_from_enum_definition(definition) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/AbcSize,Metrics/CyclomaticComplexity
      variants =
        if definition[:_enum].is_a?(Array)
          # Simple array enum:
          # {
          #   _enum: ['A', 'B', 'C']
          # }
          definition[:_enum].map.with_index do |variant_name, index|
            ScaleRb::PortableType::SimpleVariant.new(variant_name, index)
          end
        elsif definition[:_enum].is_a?(Hash)
          if _indexed_enum?(definition)
            # Indexed enum:
            # {
            #   _enum: {
            #     Variant1: 0,
            #     Variant2: 1,
            #     Variant3: 2
            #   }
            # }
            definition[:_enum].map do |variant_name, index|
              ScaleRb::PortableType::SimpleVariant.new(variant_name, index)
            end
          else
            # Mixed enum:
            # {
            #   _enum: {
            #     Variant1: 'Null',
            #     Variant2: {
            #       name: 'Text',
            #       value: 'u32'
            #     },
            #     Variant3: ['u8', 'bool', 'Vec<u32>']
            #   }
            # }
            definition[:_enum].map.with_index do |(variant_name, variant_def), index|
              case variant_def
              when String
                ScaleRb::PortableType::SimpleVariant.new(variant_name, index)
              when Array
                ScaleRb::PortableType::TupleVariant.new(
                  variant_name,
                  index,
                  variant_def.map { |field_type| use(field_type) }
                )
              when Hash
                ScaleRb::PortableType::StructVariant.new(
                  variant_name,
                  index,
                  variant_def.map do |field_name, field_type|
                    ScaleRb::PortableType::Field.new(field_name, use(field_type))
                  end
                )
              else
                raise "Unknown variant type for #{variant_name}: #{variant_def.class}"
              end
            end
          end
        end
      ScaleRb::PortableType::VariantType.new(variants)
    end

    # % _build_portable_type_from_struct_definition :: Hash<Symbol, Any> -> StructType
    def _build_portable_type_from_struct_definition(definition)
      fields = definition[:_struct].map do |field_name, field_type|
        ScaleRb::PortableType::Field.new(field_name, use(field_type))
      end
      ScaleRb::PortableType::StructType.new(fields)
    end
  end
end
