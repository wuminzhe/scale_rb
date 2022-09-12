# frozen_string_literal: true

require 'scale_rb_2/version'
require 'registry'
require 'monkey_patching'
require 'logger'

def bytes?(type)
  type.downcase == 'bytes'
end

def boolean?(type)
  type.downcase == 'boolean'
end

def string?(type)
  type.downcase == 'string'
end

def compact?(type)
  type.downcase == 'compact'
end

def array?(type)
  type[0] == '[' && type[-1] == ']'
end

def int?(type)
  type[0].downcase == 'i' && type[1..] =~ /\A(8|16|32|64|128|256|512)\z/
end

def uint?(type)
  type[0].downcase == 'u' && type[1..] =~ /\A(8|16|32|64|128|256|512)\z/
end

def vec?(type)
  type[0..3].downcase == 'vec<' && type[-1] == '>'
end

def tuple?(type)
  type[0] == '(' && type[-1] == ')'
end

def struct?(type)
  type.instance_of?(Hash)
end

def enum?(type)
  type.instance_of?(Hash) && type.key?(:_enum)
end

def parse_fixed_array(type)
  scan_out = type.scan(/\A\[\s*(.+)\s*;\s*(\d+)\s*\]\z/)
  raise ScaleRb2::TypeParseError, type if scan_out.empty?
  raise ScaleRb2::TypeParseError, type if scan_out[0].length != 2

  inner_type = scan_out[0][0]
  length = scan_out[0][1].to_i
  [inner_type, length]
end

# main module
module ScaleRb2
  class Error < StandardError; end
  class NotImplemented < Error; end
  class NilTypeError < Error; end
  class TypeParseError < Error; end
  class NotEnoughBytesError < Error; end
  class InvalidBytesError < Error; end
  class Unreachable < Error; end
  class IndexOutOfRangeError < Error; end
  class LengthNotEqualErr < Error; end
  class InvalidValueError < Error; end

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout)
      @logger.level = Logger::INFO
      @logger
    end

    def get_final_type_from_registry(registry, type)
      mapped_type = registry[type]
      if mapped_type.nil?
        nil
      elsif registry[mapped_type].nil?
        mapped_type
      else
        get_final_type_from_registry(registry, mapped_type)
      end
    end

    def decode(type, bytes)
      logger.debug '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'
      logger.debug "           type: #{type}"
      logger.debug "          bytes: #{bytes}"

      value, remaining_bytes = do_decode(type, bytes)

      logger.debug "        decoded: #{value}"
      logger.debug "remaining bytes: #{remaining_bytes}"

      [value, remaining_bytes]
    end

    def encode(type, value)
      logger.debug '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
      logger.debug "           type: #{type}"
      logger.debug "          value: #{value}"

      bytes = do_encode(type, value)

      logger.debug "        encoded: #{bytes}"
      bytes
    end
  end

  def self.do_decode(type, bytes, registry = {})
    if type.instance_of?(String)
      return decode_bytes(bytes) if bytes?(type) # Bytes
      return decode_boolean(bytes) if boolean?(type) # Boolean
      return decode_string(bytes) if string?(type) # String
      return decode_compact(bytes) if compact?(type) # Compact
      return decode_int(type, bytes) if int?(type) # i8, i16...
      return decode_uint(type, bytes) if uint?(type) # u8, u16...
      return decode_array(type, bytes, registry) if array?(type) # [u8; 3]
      return decode_vec(type, bytes, registry) if vec?(type) # Vec<u8>
      return decode_tuple(type, bytes, registry) if tuple?(type) # (u8, u8)

      registry_type = get_final_type_from_registry(registry, type)
      return do_decode(registry_type, bytes, registry) if registry_type
    elsif type.instance_of?(Hash)
      return decode_enum(type, bytes, registry) if enum?(type)
      return decode_struct(type, bytes, registry) if struct?(type)
    end

    raise NotImplemented, "type: #{type.inspect}, bytes: #{bytes}"
  end

  def self.decode_bytes(bytes)
    length, remaining_bytes = decode_compact(bytes)
    [
      remaining_bytes[0...length],
      remaining_bytes[length..]
    ]
  end

  def self.decode_boolean(bytes)
    return [false, bytes[1..]] if bytes[0] == 0x00
    return [true, bytes[1..]] if bytes[0] == 0x01

    raise InvalidBytesError, "type: Boolean, bytes: #{bytes}"
  end

  def self.encode_boolean(value)
    return [0x00] if value == false
    return [0x01] if value == true

    raise InvalidValueError, "type: Boolean, value: #{value.inspect}"
  end

  def self.decode_string(bytes)
    length, remaining_bytes = decode_compact(bytes)
    raise NotEnoughBytesError, "type: String, bytes: #{bytes}" if remaining_bytes.length < length

    [
      remaining_bytes[0...length].to_utf8,
      remaining_bytes[length..]
    ]
  end

  def self.encode_string(string)
    body = string.unpack('C*')
    prefix = encode_compact(body.length)
    prefix + body
  end

  def self.decode_enum(enum_type, bytes, registry = {})
    index = bytes[0]
    raise IndexOutOfRangeError, "type: #{enum_type}, bytes: #{bytes}" if index > enum_type[:_enum].length - 1

    key = enum_type[:_enum].keys[index]
    type = enum_type[:_enum].values[index]

    value, remaining_bytes = do_decode(type, bytes[1..], registry)
    [{ key => value }, remaining_bytes]
  end

  def self.decode_struct(struct, bytes, registry = {})
    values, remaining_bytes = decode_types(struct.values, bytes, registry)
    [
      [struct.keys, values].transpose.to_h,
      remaining_bytes
    ]
  end

  def self.decode_tuple(tuple_type, bytes, registry = {})
    inner_types = tuple_type.scan(/\A\(\s*(.+)\s*\)\z/)[0][0].split(',').map(&:strip)
    decode_types(inner_types, bytes, registry)
  end

  # # tail recursion
  # def self.decode_types_2(types, bytes, result = [])
  #   if types.empty?
  #     result
  #   else
  #     value, remaining_bytes = do_decode(types[0], bytes)
  #     new_result = result.empty? ? [[value], remaining_bytes] : [result[0] + [value], remaining_bytes]
  #     decode_types(types[1..], remaining_bytes, new_result)
  #   end
  # end

  # def self.decode_2(type)
  #   lambda do |bytes|
  #     value = type.to_s
  #     [value, bytes[1..]]
  #   end
  # end
  #
  # {
  #   bytes = [1, 2, 3]
  #   decode_2('Compact').call(bytes)
  # }
  #
  def self.decode_types(type_list, bytes, registry = {})
    if type_list.empty?
      [[], bytes]
    else
      value, remaining_bytes = do_decode(type_list.first, bytes, registry)
      value_list, remaining_bytes = decode_types(type_list[1..], remaining_bytes, registry)
      [[value] + value_list, remaining_bytes]
    end
  end

  def self.decode_compact(bytes)
    case bytes[0] & 3
    when 0
      [bytes[0] >> 2, bytes[1..]]
    when 1
      [bytes[0..1].flip.to_uint >> 2, bytes[2..]]
    when 2
      [bytes[0..3].flip.to_uint >> 2, bytes[4..]]
    when 3
      length = 4 + (bytes[0] >> 2)
      [bytes[1..length].flip.to_uint, bytes[length + 1..]]
    else
      raise Unreachable, "type: Compact, bytes: #{bytes}"
    end
  end

  def self.decode_array(type, bytes, registry = {})
    inner_type, length = parse_fixed_array(type)
    decode_fixed_array(inner_type, length, bytes, registry)
  end

  def self.decode_fixed_array(inner_type, length, bytes, registry = {})
    if length >= 1
      value, remaining_bytes = do_decode(inner_type, bytes, registry)
      arr, remaining_bytes = decode_fixed_array(inner_type, length - 1, remaining_bytes, registry)
      [[value] + arr, remaining_bytes]
    else
      [[], bytes]
    end
  end

  def self.decode_vec(type, bytes, registry = {})
    inner_type = type.scan(/\AVec<(.+)>\z/).first.first
    length, remaining_bytes = decode_compact(bytes)
    decode_fixed_array(inner_type, length, remaining_bytes, registry)
  end

  def self.decode_int(type, bytes)
    bit_length = type[1..].to_i
    byte_length = bit_length / 8
    raise NotEnoughBytesError, "type: #{type}, bytes: #{bytes}" if bytes.length < byte_length

    [
      bytes[0...byte_length].flip.to_int(bit_length),
      bytes[byte_length..]
    ]
  end

  def self.decode_uint(type, bytes)
    bit_length = type[1..].to_i
    byte_length = bit_length / 8
    raise NotEnoughBytesError, "type: #{type}, bytes: #{bytes}" if bytes.length < byte_length

    [
      bytes[0...byte_length].flip.to_uint,
      bytes[byte_length..]
    ]
  end

  def self.do_encode(type, value, registry = {})
    if type.instance_of?(String)
      return encode_bytes(value) if bytes?(type)
      return encode_boolean(value) if boolean?(type)
      return encode_string(value) if string?(type)
      return encode_compact(value) if compact?(type)
      return encode_uint(type, value) if uint?(type)
      return encode_array(type, value, registry) if array?(type)
      return encode_vec(type, value, registry) if vec?(type)
      return encode_tuple(type, value, registry) if tuple?(type)

      registry_type = get_final_type_from_registry(registry, type)
      return do_encode(registry_type, value, registry) if registry_type
    elsif type.instance_of?(Hash)
      return encode_enum(type, value, registry) if enum?(type)
      return encode_struct(type, value, registry) if struct?(type)
    end

    raise NotImplemented, "type: #{type}, value: #{value.inspect}"
  end

  def self.encode_bytes(value)
    encode_compact(value.length) + value
  end

  def self.encode_array(type, array, registry = {})
    inner_type, length = parse_fixed_array(type)
    raise LengthNotEqualErr, "type: #{type}, value: #{array.inspect}" if length != array.length

    encode_fixed_array(inner_type, array, registry)
  end

  def self.encode_vec(type, array, registry = {})
    inner_type = type.scan(/\AVec<(.+)>\z/).first.first
    encode_compact(array.length) +
      array.reduce([]) do |bytes, value|
        bytes + do_encode(inner_type, value, registry)
      end
  end

  def self.encode_fixed_array(inner_type, array, registry = {})
    if array.length >= 1
      bytes = do_encode(inner_type, array[0], registry)
      bytes + encode_fixed_array(inner_type, array[1..], registry)
    else
      []
    end
  end

  def self.encode_uint(type, value)
    bit_length = type[1..].to_i
    value.to_bytes(bit_length).flip
  end

  def self.encode_compact(value)
    return [value << 2] if (value >= 0) && (value < 64)
    return ((value << 2) + 1).to_bytes.flip if value < 2**14
    return ((value << 2) + 2).to_bytes.flip if value < 2**30

    bytes = value.to_bytes.flip
    [(((bytes.length - 4) << 2) + 3)] + bytes
  end

  def self.encode_enum(enum_type, enum, registry = {})
    key = enum.keys.first
    value = enum.values.first
    value_type = enum_type[:_enum][key]
    index = enum_type[:_enum].keys.index(key)
    encode_uint('u8', index) + do_encode(value_type, value, registry)
  end

  def self.encode_tuple(tuple_type, tuple, registry = {})
    inner_types = tuple_type.scan(/\A\(\s*(.+)\s*\)\z/)[0][0].split(',').map(&:strip)
    encode_types(inner_types, tuple, registry)
  end

  def self.encode_types(type_list, value_list, registry = {})
    raise LengthNotEqualErr, "type: #{type_list}, value: #{value_list.inspect}" if type_list.length != value_list.length

    if type_list.empty?
      []
    else
      bytes = do_encode(type_list.first, value_list.first, registry)
      bytes + encode_types(type_list[1..], value_list[1..], registry)
    end
  end

  def self.encode_struct(struct_type, struct, registry = {})
    encode_types(struct_type.values, struct.values, registry)
  end
end
