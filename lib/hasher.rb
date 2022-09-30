# frozen_string_literal: true

require 'xxhash'
require 'blake2b'

module Hasher
  def self.identity(bytes)
    bytes.to_hex[2..]
  end

  def self.twox64(data)
    result = XXhash.xxh64 data, 0
    bytes = result.to_bytes.reverse
    bytes.to_hex[2..]
  end

  def self.twox128(data)
    bytes = []
    2.times do |i|
      result = XXhash.xxh64 data, i
      bytes += result.to_bytes.reverse
    end
    bytes.to_hex[2..]
  end

  def self.twox64_concat(bytes)
    data = bytes.to_utf8
    twox64(data) + bytes.to_hex[2..]
  end

  def self.blake2_128(bytes)
    Blake2b.hex bytes, 16
  end

  def self.blake2_256(bytes)
    Blake2b.hex bytes, 32
  end

  def self.blake2128_concat(bytes)
    blake2_128(bytes) + bytes.to_hex[2..]
  end
end
