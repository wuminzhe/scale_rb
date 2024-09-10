# frozen_string_literal: true

module ScaleRb
  class << self
    # % build_types :: Array<Hash> -> Array<PortableType>
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
        return ScaleRb::StructType.new(
          fields.map do |f|
            Field.new(f._get(:name), f._get(:type))
          end
        )
      when :variant
        variants = type_def._get(:variants)
        return ScaleRb::VariantType.new([]) if variants.empty?

        variant_list = variants.map do |v|
          fields = v._get(:fields)
          if fields.empty?
            ScaleRb::SimpleVariant.new(v._get(:name), v._get(:index))
          else
            first_field_name = fields.first._get(:name)
            if first_field_name.nil?
              ScaleRb::TupleVariant.new(
                v._get(:name),
                v._get(:index),
                fields.map { |f| f._get(:type) }
              )
            else
              ScaleRb::StructVariant.new(
                v._get(:name),
                v._get(:index),
                fields.map { |f| Field.new(f._get(:name), f._get(:type)) }
              )
            end
          end
        end
        return ScaleRb::VariantType.new(variant_list)
      end
    end
  end

  # % type Ti = Integer
  # % type U8 = 0 | 1 | .. | 255
  # % type U8Array = Array<U8>
  # % type Hex = `0x${String}`;
  # % type Primitive = 'I8' | 'U8' | 'I16' | 'U16' | 'I32' | 'U32' | 'I64' | 'U64' | 'I128' | 'U128' | 'I256' | 'U256' | 'Bool' | 'Str' | 'Char'
  # % type PortableType = PrimitiveType | CompactType | SequenceType | BitSequenceType | ArrayType | TupleType | StructType | VariantType

  class PrimitiveType
    # % primitve :: Primitive
    attr_reader :primitive

    # % initialize :: Primitive -> void
    def initialize(primitive)
      @primitive = primitive
    end
  end

  class CompactType
    # % type :: Ti
    attr_reader :type

    # % initialize :: Ti -> void
    def initialize(type)
      @type = type
    end
  end

  class SequenceType
    # % type :: Ti
    attr_reader :type

    # % initialize :: Ti -> void
    def initialize(type)
      @type = type
    end
  end

  class BitSequenceType
    # % bit_store_type :: Ti
    attr_reader :bit_store_type

    # % bit_order_type :: Ti
    attr_reader :bit_order_type

    # % initialize :: Ti -> Ti -> void
    def initialize(bit_store_type, bit_order_type)
      @bit_store_type = bit_store_type
      @bit_order_type = bit_order_type
    end
  end

  class ArrayType
    # % len :: Integer
    attr_reader :len

    # % type :: Ti
    attr_reader :type

    # % initialize :: Integer -> Ti -> void
    def initialize(len, type)
      @len = len
      @type = type
    end
  end

  class TupleType
    # % tuple :: Array<Ti>
    attr_reader :tuple

    # % initialize :: Array<Ti> -> void
    def initialize(tuple)
      @tuple = tuple
    end
  end

  class Field
    # % name :: String
    attr_reader :name

    # % type :: Ti
    attr_reader :type

    # % initialize :: String -> Ti -> void
    def initialize(name, type)
      @name = name
      @type = type
    end
  end

  class StructType
    # % fields :: Array<Field>
    attr_reader :fields

    # % initialize :: Array<Field> -> void
    def initialize(fields)
      @fields = fields
    end
  end

  class UnitType
    # % initialize :: void
    def initialize
    end
  end


  class SimpleVariant
    # % name :: String
    attr_reader :name
    # % index :: Integer
    attr_reader :index

    # % initialize :: String -> Integer -> void
    def initialize(name, index)
      @name = name
      @index = index
    end
  end

  class TupleVariant
    # % name :: String
    attr_reader :name
    # % index :: Integer
    attr_reader :index
    # % tuple :: TupleType
    attr_reader :tuple

    # % initialize :: String -> Integer -> Array<Ti> -> void
    def initialize(name, index, types)
      @name = name
      @index = index
      @tuple = TupleType.new(types)
    end
  end

  class StructVariant
    # % name :: String
    attr_reader :name
    # % index :: Integer
    attr_reader :index
    # % struct :: StructType
    attr_reader :struct

    # % initialize :: String -> Integer -> Array<Field> -> void
    def initialize(name, index, fields)
      @name = name
      @index = index
      @struct = StructType.new(fields)
    end
  end

  class VariantType
    # % variants :: Array<(SimpleVariant | TupleVariant | StructVariant)>
    attr_reader :variants

    # % initialize :: Array<(SimpleVariant | TupleVariant | StructVariant)> -> void
    def initialize(variants)
      @variants = variants
    end
  end

end
