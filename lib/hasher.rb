# frozen_string_literal: true

require 'xxhash'
require 'blake2b'

module ScaleRb
  module Hasher
    class << self
      # params:
      #   hasher: 'Identity' | 'Twox64Concat' | 'Blake2128Concat'
      #    bytes: u8 array
      # return: u8 array
      def apply_hasher(hasher, bytes)
        function_name = hasher.gsub('_', '').sr_underscore
        Hasher.send(function_name, bytes)
      end
    end

    class << self
      def identity(bytes)
        bytes
      end

      def twox64_concat(bytes)
        data = bytes.to_utf8
        twox64(data) + bytes
      end

      def blake2128_concat(bytes)
        blake2_128(bytes) + bytes
      end

      def twox64(str)
        result = XXhash.xxh64 str, 0
        result.to_bytes.reverse
      end

      def twox128(str)
        bytes = []
        2.times do |i|
          result = XXhash.xxh64 str, i
          bytes += result.to_bytes.reverse
        end
        bytes
      end

      def blake2_128(bytes)
        Blake2b.hex(bytes, 16).to_bytes
      end

      def blake2_256(bytes)
        Blake2b.hex(bytes, 32).to_bytes
      end
    end
  end
end
