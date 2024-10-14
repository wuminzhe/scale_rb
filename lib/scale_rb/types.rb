# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

module ScaleRb
  module Types
    include Dry.Types()

    Primitive = Types::Strict::Symbol.enum(
      :I8, :U8, :I16, :U16, :I32, :U32, :I64, :U64, :I128, :U128, :I256, :U256, :Bool, :Str, :Char
    )
    Ti = Types::Strict::Integer | Types::Strict::String
    # U8 = Types::Strict::Integer.constrained(gteq: 0, lt: 256)
    U8 = Types::Strict::Integer
    U8Array = Types::Strict::Array.of(U8)
    Hex = Types::Strict::String.constrained(format: /\A0x[0-9a-fA-F]+\z/)

    Registry = Types.Interface(:[])

    HashMap = lambda do |key_type, value_type|
      Types::Hash.map(key_type, value_type)
    end
    UnsignedInteger = Types::Strict::Integer.constrained(gteq: 0)
    TypedArray = ->(type) { Types::Array.of(type) }

    class Base < Dry::Struct
      attribute? :registry, Registry
      attribute? :path, Types::Strict::Array.of(Types::Strict::String)

      def t(type_id)
        raise 'No registry' unless registry

        pt = registry[type_id]
        raise "Unknown type: #{type_id}" unless pt

        pt
      end

      def to_s
        to_string
      end

      MAX_DEPTH = 2
      def to_string(_depth = 0)
        raise NotImplementedError, "#{self.class} must implement to_string"
      end
    end

    class PrimitiveType < Base
      attribute :primitive, Primitive

      def to_string(_depth = 0)
        primitive.to_s
      end
    end

    class CompactType < Base
      attribute? :type, Ti

      def to_string(depth = 0)
        if type
          if depth > MAX_DEPTH
            'Compact<...>'
          else
            "Compact<#{t(type).to_string(depth + 1)}>"
          end
        else
          'Compact'
        end
      end
    end

    class SequenceType < Base
      attribute :type, Ti

      def to_string(depth = 0)
        if depth > MAX_DEPTH
          '[...]'
        else
          "[#{t(type).to_string(depth + 1)}]"
        end
      end
    end

    class BitSequenceType < Base
      attribute :bit_store_type, Ti
      attribute :bit_order_type, Ti

      def to_string(depth = 0)
        if depth > MAX_DEPTH
          'BitSequence<...>'
        else
          "BitSequence<#{t(bit_store_type).to_string(depth + 1)}, #{t(bit_order_type).to_string(depth + 1)}>"
        end
      end
    end

    class ArrayType < Base
      attribute :len, Types::Strict::Integer
      attribute :type, Ti

      def to_string(depth = 0)
        if depth > MAX_DEPTH
          '[...]'
        else
          "[#{t(type).to_string(depth + 1)}; #{len}]"
        end
      end
    end

    class TupleType < Base
      attribute :tuple, Types::Strict::Array.of(Ti)

      def to_string(depth = 0)
        if depth > MAX_DEPTH
          '(...)'
        else
          "(#{tuple.map { |t| t(t).to_string(depth + 1) }.join(', ')})"
        end
      end
    end

    class Field < Dry::Struct
      attribute :name, Types::Strict::String
      attribute :type, Ti
    end

    class StructType < Base
      attribute :fields, Types::Strict::Array.of(Field)

      def to_string(depth = 0)
        if depth > MAX_DEPTH
          '{ ... }'
        else
          "{ #{fields.map { |field| "#{field.name}: #{t(field.type).to_string(depth + 1)}" }.join(', ')} }"
        end
      end
    end

    class UnitType < Base
      def to_string(_depth = 0)
        '()'
      end
    end

    class SimpleVariant < Dry::Struct
      attribute :name, Types::Strict::Symbol
      attribute :index, Types::Strict::Integer
    end

    class TupleVariant < Dry::Struct
      attribute :name, Types::Strict::Symbol
      attribute :index, Types::Strict::Integer
      attribute :tuple, TupleType
    end

    class StructVariant < Dry::Struct
      attribute :name, Types::Strict::Symbol
      attribute :index, Types::Strict::Integer
      attribute :struct, StructType
    end

    VariantKind = Instance(SimpleVariant) | Instance(TupleVariant) | Instance(StructVariant)

    class VariantType < Base
      attribute :variants, Types::Array.of(VariantKind)

      def to_string(depth = 0)
        if depth > MAX_DEPTH
          variants.sort_by(&:index).map { |v| v.name.to_s }.join(' | ')
        else
          variants.sort_by(&:index).map do |v|
            case v
            when SimpleVariant
              v.name.to_s
            when TupleVariant
              "#{v.name}#{v.tuple.to_string(depth + 1)}"
            when StructVariant
              "#{v.name} #{v.struct.to_string(depth + 1)}"
            end
          end.join(' | ')
        end
      end

      def self.option(type, registry)
        VariantType.new(
          variants: [
            SimpleVariant.new(name: :None, index: 0),
            TupleVariant.new(name: :Some, index: 1, tuple: TupleType.new(tuple: [type], registry:))
          ],
          registry:
        )
      end

      def option?
        variants.length == 2 &&
          variants.any? { |v| v.is_a?(SimpleVariant) && v.name == :None && v.index == 0 } &&
          variants.any? { |v| v.is_a?(TupleVariant) && v.name == :Some && v.index == 1 }
      end

      def self.result(ok_type, err_type, registry)
        VariantType.new(
          variants: [
            TupleVariant.new(name: :Ok, index: 0, tuple: TupleType.new(tuple: [ok_type], registry:)),
            TupleVariant.new(name: :Err, index: 1, tuple: TupleType.new(tuple: [err_type], registry:))
          ],
          registry:
        )
      end
    end

    PortableType = Instance(VariantType) |
                   Instance(StructType) |
                   Instance(TupleType) |
                   Instance(ArrayType) |
                   Instance(CompactType) |
                   Instance(PrimitiveType) |
                   Instance(UnitType) |
                   Instance(SequenceType) |
                   Instance(BitSequenceType)

    DecodeResult = lambda do |type|
      Types::Array.of(Types::Any).constrained(size: 2).constructor do |arr|
        [type[arr[0]], arr[1]] # U8Array[arr[1]], but performance is not good.
      end
    end
  end
end

# type = ScaleRb::Types::TypedArray[ScaleRb::Types::UnsignedInteger]
# p type
# p type[[1, 2]] # => [1, 2]
# # p type[[-1, -2]] # => -1 violates constraints (gteq?(0, -1) failed)
