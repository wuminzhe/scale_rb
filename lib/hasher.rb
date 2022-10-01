# frozen_string_literal: true

require 'xxhash'
require 'blake2b'

module Hasher
  class << self
    # hasher: 'Identity', 'Twox64Concat', 'Blake2128Concat'
    # bytes: u8 array
    def apply_hasher(hasher, bytes)
      function_name = hasher.gsub('_', '').underscore
      Hasher.send(function_name, bytes)
    end
  end

  class << self
    def identity(bytes)
      bytes.to_hex[2..]
    end

    def twox64_concat(bytes)
      data = bytes.to_utf8
      twox64(data) + bytes.to_hex[2..]
    end

    def blake2128_concat(bytes)
      blake2_128(bytes) + bytes.to_hex[2..]
    end

    def twox64(str)
      result = XXhash.xxh64 str, 0
      bytes = result.to_bytes.reverse
      bytes.to_hex[2..]
    end

    def twox128(str)
      bytes = []
      2.times do |i|
        result = XXhash.xxh64 str, i
        bytes += result.to_bytes.reverse
      end
      bytes.to_hex[2..]
    end

    def blake2_128(bytes)
      Blake2b.hex bytes, 16
    end

    def blake2_256(bytes)
      Blake2b.hex bytes, 32
    end
  end
end
