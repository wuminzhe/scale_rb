# frozen_string_literal: true

require_relative './type_exp'
require_relative '../types'

# rubocop:disable all
module ScaleRb
  module Metadata
    class Registry
      include Types

      # Map name to index of type in `types` array
      # % lookup :: String -> Integer
      attr_reader :lookup

      # % keys :: Integer -> String
      attr_reader :keys

      # % types :: Array<PortableType>
      attr_reader :types

      attr_reader :old_types

      # % initialize :: Hash<Symbol, Any> -> void
      def initialize(old_types)
        @old_types = old_types
        @lookup = {}
        @keys = {}
        @types = []

        build()
      end

      def build()
        @old_types.keys.each do |name|
          use(name.to_s)
        end
      end

      def [](index)
        @types[index]
      end

      def inspect
        "registry(#{@types.length} types)"
      end

      def to_s
        @types.map.with_index do |type, index|
          "#{@keys[index]} => #{type.to_s}"
        end.join("\n")
      end

      # % use :: String -> Integer
      def use(old_type_exp)
        raise "Empty old_type_exp: #{old_type_exp}" if old_type_exp.nil? || old_type_exp.strip == ''

        ast_type = TypeExp.parse(old_type_exp)
        raise "No AST type for #{old_type_exp}" if ast_type.nil?

        key = ast_type.to_s
        ti = lookup[key]
        return ti if ti

        ti = @types.length
        @types[ti] = "Placeholder"
        @lookup[key] = ti
        @keys[ti] = key
        @types[ti] = build_portable_type(ast_type)
        ti
      end

      # % build_portable_type :: NamedType | ArrayType | TupleType -> PortableType
      # __ :build_portable_type, { ast_type: TypedArray[TypeExp::ArrayType | TypeExp::TupleType | TypeExp::NamedType] } => PortableType
      def build_portable_type(ast_type)
        case ast_type
        when TypeExp::ArrayType
          ArrayType.new(use(ast_type.item), ast_type.len, registry: self)
        when TypeExp::TupleType
          TupleType.new(ast_type.params.map { |param| use(param) })
        when TypeExp::NamedType
          build_portable_type_from_named_type(ast_type)
        else
          raise "Unknown type: #{ast_type.class}"
        end
      end

      # % build_portable_type_from_named_type :: NamedType -> PortableType
      def build_portable_type_from_named_type(named_type)
        name = named_type.name
        params = named_type.params

        definition = @old_types[name.to_sym]
        return build_from_definition(name, definition) if definition

        primitive = as_primitive(name)
        return primitive if primitive

        case name
        when 'Vec'
          item_index = use(params[0].to_s)
          SequenceType.new(type: item_index, registry: self)
        when 'Option'
          item_index = use(params[0].to_s)
          VariantType.option(item_index, self)
        when 'Result'
          ok_index = use(params[0].to_s)
          err_index = use(params[1].to_s)
          VariantType.result(ok_index, err_index, self)
        when 'Compact'
          # item_index = use(params[0].to_s)
          # CompactType.new(type: item_index, registry: self)
          CompactType.new
        when 'Null'
          UnitType.new
        else
          raise "Unknown type: #{name}"
        end
      end

      # % as_primitive :: String -> PrimitiveType | nil
      def as_primitive(name)
        case name.downcase
        when /^i\d+$/
          PrimitiveType.new(primitive: "I#{name[1..]}".to_sym)
        when /^u\d+$/
          PrimitiveType.new(primitive: "U#{name[1..]}".to_sym)
        when /^bool$/
          PrimitiveType.new(primitive: :Bool)
        when /^str$/, /^text$/
          PrimitiveType.new(primitive: :Str)
        else
          nil
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
          # TypeAlias.new(name, use(definition))
          alias_type_id = use(definition)
          # p "alias_type_id: #{alias_type_id}"
          types[alias_type_id]
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
        definition[:_enum].is_a?(::Hash) && definition[:_enum].values.all? { |value| value.is_a?(::Integer) }
      end

      # % _build_portable_type_from_enum_definition :: Hash<Symbol, Any> -> VariantType
      def _build_portable_type_from_enum_definition(definition)
        variants =
          if definition[:_enum].is_a?(::Array)
            # Simple array enum:
            # {
            #   _enum: ['A', 'B', 'C']
            # }
            definition[:_enum].map.with_index do |variant_name, index|
              SimpleVariant.new(name: variant_name.to_sym, index:)
            end
          elsif definition[:_enum].is_a?(::Hash)
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
                SimpleVariant.new(name: variant_name, index:)
              end
            else
              # Mixed enum:
              # {
              #   _enum: {
              #     A: 'u32',
              #     B: {a: 'u32', b: 'u32'},
              #     C: null,
              #     D: ['u32', 'u32']
              #   }
              # }
              definition[:_enum].map.with_index do |(variant_name, variant_def), index|
                case variant_def
                when ::String
                  TupleVariant.new(
                    name: variant_name,
                    index:,
                    tuple: TupleType.new(
                      tuple: [use(variant_def)],
                      registry: self
                    ),
                  )
                when ::Array
                  TupleVariant.new(
                    name: variant_name,
                    index:,
                    tuple: TupleType.new(
                      tuple: variant_def.map { |field_type| use(field_type) },
                      registry: self
                    )
                  )
                when ::Hash
                  StructVariant.new(
                    name: variant_name,
                    index:,
                    struct: StructType.new(
                      fields: variant_def.map do |field_name, field_type|
                        Field.new(name: field_name.to_s, type: use(field_type))
                      end,
                      registry: self
                    )
                  )
                else
                  raise "Unknown variant type for #{variant_name}: #{variant_def.class}"
                end
              end
            end
          end
        VariantType.new(variants:, registry: self)
      end

      # % _build_portable_type_from_struct_definition :: Hash<Symbol, Any> -> StructType
      def _build_portable_type_from_struct_definition(definition)
        fields = definition.map do |field_name, field_type|
          Field.new(name: field_name.to_s, type: use(field_type))
        end
        StructType.new(fields:, registry: self)
      end
    end
  end
end

# require_relative '../../metadata/metadata'

# begin
#   registry = ScaleRb::Metadata::Registry.new ScaleRb::Metadata::TYPES
#   puts registry
# rescue StandardError => e
#   puts e.message
#   puts e.backtrace.join("\n")
# end
