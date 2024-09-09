# frozen_string_literal: true

module ScaleRb
  class << self
    # - build_types :: [Object] -> [PortableType]
    def build_types(data)
      data.map.with_index do |type, i|
        id = type._get(:id)
        raise "Invalid type id: #{id}" if id.nil? || id != i

        def_ = type._get(:type, :def)
        raise "No 'def' found: #{type}" if def_.nil?

        type_name = def_.keys.first.to_sym
        type_def = def_._get(type_name)
        _build_type(type_name, type_def)
      end
    end

    private 

    def _build_type(type_name, type_def)
      case type_name
      when :primitive
        ScaleRb::PrimitiveType.new(type_def)
      when :compact
        ScaleRb::CompactType.new(type_def._get(:type))
      when :sequence
        ScaleRb::SequenceType.new(type_def._get(:type))
      when :bitSequence
        ScaleRb::BitSequenceType.new(
          type_def._get(:bitStoreType),
          type_def._get(:bitOrderType)
        )
      when :array
        ScaleRb::ArrayType.new(
          type_def._get(:len),
          type_def._get(:type)
        )
      when :tuple
        ScaleRb::TupleType.new(type_def)
      when :composite
        fields = type_def._get(:fields)
        first_field = fields.first

        return ScaleRb::UnitType.new unless first_field
        return ScaleRb::TupleType.new(fields.map { |f| f._get(:type) }) unless first_field._get(:name)
        return ScaleRb::CompositeType.new(
          fields.map do |f|
            Field.new(f._get(:name), f._get(:type))
          end
        )
      when :variant
        variants = type_def._get(:variants)
        first_variant = variants.first
        return ScaleRb::VariantType.new([]) if first_variant.nil? # sp_core::Void

        fields_of_first_variant = first_variant._get(:fields)
        first_field_of_first_variant = fields_of_first_variant.first
        variant_list = 
          case first_field_of_first_variant
          when nil
            variants.map { |v| ScaleRb::SimpleVariant.new(v._get(:name), v._get(:index)) } 
          else
            case first_field_of_first_variant._get(:name)
            when nil
              variants.map do |v|
                fields = v._get(:fields)
                types = fields.map { |f| f._get(:type) }
                TupleVariant.new(v._get(:name), v._get(:index), types)
              end
            else
              variants.map do |v|
                fields = v._get(:fields)
                fields = fields.map { |f| Field.new(f._get(:name), f._get(:type)) }
                StructVariant.new(v._get(:name), v._get(:index), fields)
              end
            end
          end

        return ScaleRb::VariantType.new(variant_list)
      end
    end
  end

  # - type Ti = Integer
  # - type Primitive = 'I8' | 'U8' | 'I16' | 'U16' | 'I32' | 'U32' | 'I64' | 'U64' | 'I128' | 'U128' | 'I256' | 'U256' | 'Bool' | 'Str' | 'Char'
  # - type PortableType = PrimitiveType | CompactType | SequenceType | BitSequenceType | ArrayType | TupleType | CompositeType | VariantType

  class Base
    # - kind :: Symbol
    attr_reader :kind
  end

  class PrimitiveType < Base
    # - primitve :: Primitive
    attr_reader :primitive

    # - initialize :: Primitive -> void
    def initialize(primitive)
      @kind = :Primitive
      @primitive = primitive
    end
  end

  class CompactType < Base
    # - type :: Ti
    attr_reader :type

    # - initialize :: Ti -> void
    def initialize(type)
      @kind = :Compact
      @type = type
    end
  end

  class SequenceType < Base
    # - type :: Ti
    attr_reader :type

    # - initialize :: Ti -> void
    def initialize(type)
      @kind = :Sequence
      @type = type
    end
  end

  class BitSequenceType < Base
    # - bit_store_type :: Ti
    attr_reader :bit_store_type

    # - bit_order_type :: Ti
    attr_reader :bit_order_type

    # - initialize :: Ti -> Ti -> void
    def initialize(bit_store_type, bit_order_type)
      @kind = :BitSequence
      @bit_store_type = bit_store_type
      @bit_order_type = bit_order_type
    end
  end

  class ArrayType < Base
    # :: Integer
    attr_reader :len

    # :: Ti
    attr_reader :type

    # - initialize :: Integer -> Ti -> void
    def initialize(len, type)
      @kind = :Array
      @len = len
      @type = type
    end
  end

  class TupleType < Base
    # :: [Ti]
    attr_reader :tuple

    # - initialize :: [Ti] -> void
    def initialize(tuple)
      @kind = :Tuple
      @tuple = tuple
    end
  end

  class Field
    # :: String
    attr_reader :name

    # :: Ti
    attr_reader :type

    # - initialize :: String -> Ti -> void
    def initialize(name, type)
      @name = name
      @type = type
    end
  end

  class CompositeType < Base
    # :: [Field]
    attr_reader :fields

    # - initialize :: [Field] -> void
    def initialize(fields)
      @kind = :Composite
      @fields = fields
    end
  end

  class UnitType < Base
    # - initialize :: void
    def initialize
      @kind = :Unit
    end
  end

  class SimpleVariant
    # - name :: String
    attr_reader :name
    # - index :: Integer
    attr_reader :index

    # - initialize :: String -> Integer -> void
    def initialize(name, index)
      @name = name
      @index = index
    end
  end

  class TupleVariant
    # - name :: String
    attr_reader :name
    # - index :: Integer
    attr_reader :index
    # - types :: [Ti]
    attr_reader :types

    # - initialize :: String -> Integer -> [Ti] -> void
    def initialize(name, index, types)
      @name = name
      @index = index
      @types = types
    end
  end

  class StructVariant
    # - name :: String
    attr_reader :name
    # - index :: Integer
    attr_reader :index
    # - fields :: [Field]
    attr_reader :fields

    # - initialize :: String -> Integer -> [Field] -> void
    def initialize(name, index, fields)
      @name = name
      @index = index
      @fields = fields
    end
  end

  class VariantType < Base
    # - variant_kind: :Simple | :Tuple | :Struct | :Void
    attr_reader :variant_kind

    # - variants :: [SimpleVariant | TupleVariant | StructVariant] | NilClass
    attr_reader :variants

    # - initialize :: SimpleVariantType | TupleVariantType | StructVariantType -> void
    def initialize(variants)
      @kind = :Variant
      @variants = variants

      if variants.nil? || variants.empty?
        @variant_kind = :Void
        @variants = nil
      else
        case variants.first
        when SimpleVariant
          @variant_kind = :Simple
        when TupleVariant
          @variant_kind = :Tuple
        when StructVariant
          @variant_kind = :Struct
        end
      end
    end
  end

end
