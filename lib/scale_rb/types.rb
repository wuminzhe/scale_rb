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

    Registry = Types.Interface(:[])
    DecodeResult = Types::Array.of(Any).constrained(size: 2).constructor do |arr|
      [arr[0], Hex[arr[1]]]
    end

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
        primitive
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
              "#{v.name}(#{v.tuple.to_string(depth + 1)})"
            when StructVariant
              "#{v.name} { #{v.struct.to_string(depth + 1)} }"
            end
          end.join(' | ')
        end
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
  end
end
