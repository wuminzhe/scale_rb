# frozen_string_literal: true

require 'xxhash'
require 'blake2b'

module ScaleRb
  module Hasher
    class << self
      # params:
      #   hasher: 'Identity' | 'Twox64Concat' | 'Blake2128Concat'
      #   bytes: u8a | hex string
      # return: u8a
      def apply_hasher(hasher, bytes)
        bytes = Utils.hex_to_u8a(bytes) if bytes.is_a?(::String)

        function_name = Utils.underscore(hasher.gsub('_', ''))
        Hasher.send(function_name, bytes)
      end
    end

    class << self
      def identity(bytes)
        bytes
      end

      def twox64_concat(bytes)
        data = Utils.u8a_to_utf8(bytes)
        twox64(data) + bytes
      end

      def blake2128_concat(bytes)
        blake2_128(bytes) + bytes
      end

      def twox64(str)
        result = XXhash.xxh64 str, 0
        Utils.hex_to_u8a(result).reverse
      end

      def twox128(str)
        bytes = []
        2.times do |i|
          result = XXhash.xxh64 str, i
          bytes += Utils.hex_to_u8a(result).reverse
        end
        bytes
      end

      def blake2_128(bytes)
        Utils.hex_to_u8a(Blake2b.hex(bytes, 16))
      end

      def blake2_256(bytes)
        Utils.hex_to_u8a(Blake2b.hex(bytes, 32))
      end
    end
  end
end
