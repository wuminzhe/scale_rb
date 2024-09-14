# frozen_string_literal: true

module ScaleRb
  # % type Ti = Integer
  # % type U8 = 0 | 1 | .. | 255
  # % type U8Array = Array<U8>
  # % type Hex = `0x${String}`;
  # % type Primitive = 'I8' | 'U8' | 'I16' | 'U16' | 'I32' | 'U32' | 'I64' | 'U64' | 'I128' | 'U128' | 'I256' | 'U256' | 'Bool' | 'Str' | 'Char'
  # % type TypeDef = PrimitiveType | CompactType | SequenceType | BitSequenceType | ArrayType | TupleType | StructType | VariantType

  class PrimitiveType
    # % primitive :: Primitive
    attr_reader :primitive

    # % initialize :: Primitive -> void
    def initialize(primitive)
      @primitive = primitive
    end

    def to_s
      @primitive
    end
  end

  class CompactType
    # % type :: Ti | NilClass
    attr_reader :type

    # % initialize :: Ti -> void
    def initialize(type = nil)
      @type = type
    end

    def to_s
      "Compact<#{@type}>"
    end
  end

  class SequenceType
    # % type :: Ti
    attr_reader :type

    # % initialize :: Ti -> void
    def initialize(type)
      @type = type
    end

    def to_s
      "[#{@type}]"
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

    def to_s
      "BitSequence<#{@bit_store_type}, #{@bit_order_type}>"
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

    def to_s
      "[#{@type}; #{@len}]"
    end
  end

  class TupleType
    # % tuple :: Array<Ti>
    attr_reader :tuple

    # % initialize :: Array<Ti> -> void
    def initialize(tuple)
      @tuple = tuple
    end

    def to_s
      tuple_str = @tuple.map(&:to_s).join(', ')
      "(#{tuple_str})"
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

    def to_s
      fields_str = @fields.map { |f| "#{f.name}: #{f.type}" }.join(', ')
      "{#{fields_str}}"
    end
  end

  class UnitType
    # % initialize :: void
    def initialize; end

    def to_s
      '()'
    end
  end

  class SimpleVariant
    # % name :: Symbol
    attr_reader :name
    # % index :: Integer
    attr_reader :index

    # % initialize :: Symbol -> Integer -> void
    def initialize(name, index)
      @name = name
      @index = index
    end

    def to_s
      @name
    end
  end

  class TupleVariant
    # % name :: Symbol
    attr_reader :name
    # % index :: Integer
    attr_reader :index
    # % tuple :: TupleType
    attr_reader :tuple

    # % initialize :: Symbol -> Integer -> Array<Ti> -> void
    def initialize(name, index, types)
      @name = name
      @index = index
      @tuple = TupleType.new(types)
    end

    def to_s
      "#{@name}: #{@tuple}"
    end
  end

  class StructVariant
    # % name :: Symbol
    attr_reader :name
    # % index :: Integer
    attr_reader :index
    # % struct :: StructType
    attr_reader :struct

    # % initialize :: Symbol -> Integer -> Array<Field> -> void
    def initialize(name, index, fields)
      @name = name
      @index = index
      @struct = StructType.new(fields)
    end

    def to_s
      "#{@name}: #{@struct}"
    end
  end

  class VariantType
    # % variants :: Array<(SimpleVariant | TupleVariant | StructVariant)>
    attr_reader :variants

    # % initialize :: Array<(SimpleVariant | TupleVariant | StructVariant)> -> void
    def initialize(variants)
      @variants = variants
    end

    def to_s
      @variants.map(&:to_s).join(' | ')
    end
  end
end
