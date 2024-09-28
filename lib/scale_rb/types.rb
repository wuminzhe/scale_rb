# frozen_string_literal: true

require 'dry-struct'
require 'dry-types'

module ScaleRb
  module Types
    include Dry.Types()

    Primitive = Types::Strict::String.enum(
      'I8', 'U8', 'I16', 'U16', 'I32', 'U32', 'I64', 'U64', 'I128', 'U128', 'I256', 'U256',
      'Bool', 'Str', 'Char'
    )
    Ti = Types::Strict::Integer.constrained(gteq: 0)
    U8 = Types::Strict::Integer.constrained(gteq: 0, lt: 256)
    U8Array = Types::Strict::Array.of(U8)
    Hex = Types::Strict::String.constrained(format: /\A0x[0-9a-fA-F]+\z/)

    Registry = Types.Interface(:get_type)
    DecodeResult = Types::Array.of(Any).constrained(size: 2).constructor do |arr|
      [arr[0], Hex[arr[1]]]
    end

    class Base < Dry::Struct
      attribute? :registry, Registry

      MAX_DEPTH = 3

      def t(type_id, depth = 0)
        raise 'No registry' unless registry

        pt = registry.get_type(type_id)
        raise "Unknown type: #{type_id}" unless pt

        return nil if depth >= MAX_DEPTH

        pt
      end

      def to_s(depth = 0)
        raise NotImplementedError, "#{self.class} must implement to_s"
      end
    end

    class PrimitiveType < Base
      attribute :primitive, Primitive

      def to_s(_depth = 0)
        primitive
      end
    end

    class CompactType < Base
      attribute? :type, Ti

      def to_s(depth = 0)
        if type
          return 'Compact<...>' if depth >= MAX_DEPTH

          "Compact<#{t(type, depth + 1)&.to_s(depth + 1)}>"
        else
          'Compact'
        end
      end
    end

    class SequenceType < Base
      attribute :type, Ti

      def to_s(depth = 0)
        return '[...]' if depth >= MAX_DEPTH

        "[#{t(type, depth + 1)&.to_s(depth + 1)}]"
      end
    end

    class BitSequenceType < Base
      attribute :bit_store_type, Ti
      attribute :bit_order_type, Ti

      def to_s(depth = 0)
        return 'BitSequence<...>' if depth >= MAX_DEPTH

        "BitSequence<#{t(bit_store_type,
                         depth + 1)&.to_s(depth + 1)}, #{t(bit_order_type, depth + 1)&.to_s(depth + 1)}>"
      end
    end

    class ArrayType < Base
      attribute :len, Types::Strict::Integer
      attribute :type, Ti

      def to_s(depth = 0)
        return '[...; ...]' if depth >= MAX_DEPTH

        "[#{t(type, depth + 1)&.to_s(depth + 1)}; #{len}]"
      end
    end

    class TupleType < Base
      attribute :tuple, Types::Strict::Array.of(Ti)

      def to_s(depth = 0)
        return '(...)' if depth >= MAX_DEPTH

        tuple_str = tuple.map { |t| t(t, depth + 1)&.to_s(depth + 1) }.join(', ')
        "(#{tuple_str})"
      end
    end

    class Field < Base
      attribute :name, Types::Strict::String
      attribute :type, Ti
    end

    class StructType < Base
      attribute :fields, Types::Strict::Array.of(Field)

      def to_s(depth = 0)
        return '{...}' if depth >= MAX_DEPTH

        fields_str = fields.map do |field|
          # field.to_s(depth + 1)
          "#{field.name}: #{t(field.type, depth + 1)&.to_s(depth + 1)}"
        end.join(', ')
        "{ #{fields_str} }"
      end
    end

    class UnitType < Base
      def to_s(_depth = 0)
        '()'
      end
    end

    class SimpleVariant < Base
      attribute :name, Types::Strict::Symbol
      attribute :index, Types::Strict::Integer

      def to_s(_depth = 0)
        name.to_s
      end
    end

    class TupleVariant < Base
      attribute :name, Types::Strict::Symbol
      attribute :index, Types::Strict::Integer
      attribute :tuple, TupleType

      def to_s(depth = 0)
        return "#{name}(...)" if depth >= MAX_DEPTH

        "#{name}#{tuple.to_s(depth + 1)}"
      end
    end

    class StructVariant < Base
      attribute :name, Types::Strict::Symbol
      attribute :index, Types::Strict::Integer
      attribute :struct, StructType

      def to_s(depth = 0)
        return "#{name} {...}" if depth >= MAX_DEPTH

        "#{name} #{struct.to_s(depth + 1)}"
      end
    end

    VariantKind = Types::Instance(SimpleVariant) | Types::Instance(TupleVariant) | Types::Instance(StructVariant)

    class VariantType < Base
      attribute :variants, Types::Array.of(VariantKind)

      def to_s(depth = 0)
        return '...' if depth >= MAX_DEPTH

        variants.map { |v| v.to_s(depth + 1) }.join(' | ')
      end
    end

    PortableType = VariantType | StructType | TupleType | ArrayType | CompactType | PrimitiveType | UnitType | SequenceType
  end
end

# p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
# puts "p0: #{p0}"

# registry = [p0]

# p1 = ScaleRb::Types::CompactType.new
# puts "p1: #{p1}"

# p2 = ScaleRb::Types::CompactType.new(type: 0, registry:)
# puts "p2: #{p2}"

# p3 = ScaleRb::Types::SequenceType.new(type: 0, registry:)
# puts "p3: #{p3}"

# p4 = ScaleRb::Types::ArrayType.new(type: 0, len: 3, registry:)
# puts "p4: #{p4}"

# registry = [p0, p1, p2, p3, p4]
# p5 = ScaleRb::Types::TupleType.new(tuple: [0, 1, 2], registry:)
# puts "p5: #{p5}"

# p6 = ScaleRb::Types::StructType.new(
#   fields: [
#     ScaleRb::Types::Field.new(name: 'name', type: 0),
#     ScaleRb::Types::Field.new(name: 'age', type: 1)
#   ],
#   registry:
# )
# puts "p6: #{p6}"

# p7 = ScaleRb::Types::UnitType.new
# puts "p7: #{p7}"

# p8 = ScaleRb::Types::VariantType.new(
#   variants: [
#     ScaleRb::Types::TupleVariant.new(name: :Bar, index: 1, tuple: p5),
#     ScaleRb::Types::SimpleVariant.new(name: :Foo, index: 0),
#     ScaleRb::Types::StructVariant.new(name: :Baz, index: 2, struct: p6)
#   ],
#   registry:
# )
# puts "p8: #{p8}"

# p ScaleRb::Types::DecodeResult[[1, '0x10']]
