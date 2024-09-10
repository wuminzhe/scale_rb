# frozen_string_literal: true

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
  end
end

require_relative 'codec/decode'
# require_relative 'codec/encode'
