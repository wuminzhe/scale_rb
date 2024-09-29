# frozen_string_literal: true

require_relative 'decode'
require_relative 'encode'

module ScaleRb
  module Codec
    class Error < StandardError; end
    class TypeNotFound < Error; end
    class TypeNotImplemented < Error; end
    class CompositeInvalidValue < Error; end
    class ArrayLengthNotEqual < Error; end
    class VariantItemNotFound < Error; end
    class VariantIndexOutOfRange < Error; end
    class VariantInvalidValue < Error; end
    class VariantFieldsLengthNotMatch < Error; end
    class LengthNotEqualErr < Error; end

    extend Decode
    extend Encode
  end
end
