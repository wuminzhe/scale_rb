# frozen_string_literal: true

require 'scale_rb_2/version'
require 'monkey_patching'
require 'logger'

def array?(type)
  type[0] == '[' && type[-1] == ']'
end

def uint?(type)
  type[0] == 'u' && type[1..] =~ /\A(8|16|32|64|128|256|512)\z/
end

def vec?(type)
  type[0..3] == 'Vec<' && type[-1] == '>'
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
    end

    def decode(type, bytes)
      logger.debug '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'
      logger.debug "           type: #{type}"
      logger.debug "          bytes: #{bytes}"
      value, remaining_bytes = do_decode(type, bytes)
      logger.debug "        decoded: #{value}"
      logger.debug "remaining bytes: #{remaining_bytes}"
      [value, remaining_bytes]
    rescue Error => e
      logger.error "          error: #{e.class}: #{e.message}"
      raise e
    end

    def encode(type, value)
      logger.debug '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
      logger.debug "           type: #{type}"
      logger.debug "          value: #{value}"
      bytes = do_encode(type, value)
      logger.debug "        encoded: #{bytes}"
      bytes
    rescue Error => e
      logger.error "          error: #{e.class}: #{e.message}"
      raise e
    end
  end

  def self.do_decode(type, bytes)
    return decode_boolean(bytes) if type == 'Boolean'
    return decode_string(bytes) if type == 'String'
    return decode_compact(bytes) if type == 'Compact'
    return decode_uint(type, bytes) if uint?(type) # u8, u16...
    return decode_array(type, bytes) if array?(type) # [u8; 3]
    return decode_vec(type, bytes) if vec?(type) # Vec<u8>
    return decode_tuple(type, bytes) if tuple?(type) # (u8, u8)
    return decode_enum(type, bytes) if enum?(type)
    return decode_struct(type, bytes) if struct?(type)

    raise NotImplemented, "type: #{enum}, bytes: #{bytes}"
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
      remaining_bytes[0...length].pack('C*').force_encoding('utf-8'),
      remaining_bytes[length..]
    ]
  end

  def self.encode_string(string)
    body = string.unpack('C*')
    prefix = encode_compact(body.length)
    prefix + body
  end

  def self.decode_enum(enum_type, bytes)
    index = bytes[0]
    raise IndexOutOfRangeError, "type: #{enum_type}, bytes: #{bytes}" if index > enum_type[:_enum].length - 1

    key = enum_type[:_enum].keys[index]
    type = enum_type[:_enum].values[index]

    value, remaining_bytes = do_decode(type, bytes[1..])
    [{ key => value }, remaining_bytes]
  end

  def self.decode_struct(struct, bytes)
    values, remaining_bytes = decode_types(struct.values, bytes)
    [
      [struct.keys, values].transpose.to_h,
      remaining_bytes
    ]
  end

  def self.decode_tuple(tuple_type, bytes)
    inner_types = tuple_type.scan(/\A\(\s*(.+)\s*\)\z/)[0][0].split(',').map(&:strip)
    decode_types(inner_types, bytes)
  end

  def self.encode_tuple(tuple_type, tuple)
    inner_types = tuple_type.scan(/\A\(\s*(.+)\s*\)\z/)[0][0].split(',').map(&:strip)
    encode_types(inner_types, tuple)
  end

  def self.encode_types(type_list, value_list)
    raise LengthNotEqualErr, "type: #{type_list}, value: #{value_list.inspect}" if type_list.length != value_list.length

    if type_list.empty?
      []
    else
      bytes = do_encode(type_list.first, value_list.first)
      bytes + encode_types(type_list[1..], value_list[1..])
    end
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
  def self.decode_types(type_list, bytes)
    if type_list.empty?
      [[], bytes]
    else
      value, remaining_bytes = do_decode(type_list.first, bytes)
      value_list, remaining_bytes = decode_types(type_list[1..], remaining_bytes)
      [[value] + value_list, remaining_bytes]
    end
  end

  def self.decode_compact(bytes)
    case bytes[0] & 3
    when 0
      [bytes[0] >> 2, bytes[1..]]
    when 1
      [bytes[0..1].to_uint >> 2, bytes[2..]]
    when 2
      [bytes[0..3].to_uint >> 2, bytes[4..]]
    when 3
      length = 4 + (bytes[0] >> 2)
      [bytes[1..length].to_uint, bytes[length + 1..]]
    else
      raise Unreachable, "type: Compact, bytes: #{bytes}"
    end
  end

  def self.decode_array(type, bytes)
    inner_type, length = parse_fixed_array(type)
    decode_fixed_array(inner_type, length, bytes)
  end

  def self.decode_fixed_array(inner_type, length, bytes)
    if length >= 1
      value, remaining_bytes = do_decode(inner_type, bytes)
      arr, remaining_bytes = decode_fixed_array(inner_type, length - 1, remaining_bytes)
      [[value] + arr, remaining_bytes]
    else
      [[], bytes]
    end
  end

  def self.decode_vec(type, bytes)
    inner_type = type.scan(/\AVec<(.+)>\z/).first.first
    length, remaining_bytes = decode_compact(bytes)
    decode_fixed_array(inner_type, length, remaining_bytes)
  end

  def self.decode_uint(type, bytes)
    bits_len = type[1..].to_i
    bytes_len = bits_len / 8
    raise NotEnoughBytesError, "type: #{type}, bytes: #{bytes}" if bytes.length < bytes_len

    [
      bytes[0...bytes_len].to_uint,
      bytes[bytes_len..]
    ]
  end

  def self.do_encode(type, value)
    return encode_boolean(value) if type == 'Boolean'
    return encode_string(value) if type == 'String'
    return encode_compact(value) if type == 'Compact'
    return encode_uint(type, value) if uint?(type)
    return encode_array(type, value) if array?(type)
    return encode_vec(type, value) if vec?(type)
    return encode_tuple(type, value) if tuple?(type)
    return encode_enum(type, value) if enum?(type)
    return encode_struct(type, value) if struct?(type)

    raise NotImplemented, "type: #{type}, value: #{value.inspect}"
  end

  def self.encode_array(type, array)
    inner_type, length = parse_fixed_array(type)
    raise LengthNotEqualErr, "type: #{type}, value: #{array.inspect}" if length != array.length

    encode_fixed_array(inner_type, array)
  end

  def self.encode_vec(type, array)
    inner_type = type.scan(/\AVec<(.+)>\z/).first.first
    do_encode('Compact', array.length) +
      array.reduce([]) do |bytes, value|
        bytes + do_encode(inner_type, value)
      end
  end

  def self.encode_fixed_array(inner_type, array)
    if array.length >= 1
      bytes = do_encode(inner_type, array[0])
      bytes + encode_fixed_array(inner_type, array[1..])
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

  def self.encode_enum(enum_type, enum)
    key = enum.keys.first
    value = enum.values.first
    value_type = enum_type[:_enum][key]
    index = enum_type[:_enum].keys.index(key)
    do_encode('u8', index) + do_encode(value_type, value)
  end

  def self.encode_struct(struct_type, struct)
    encode_types(struct_type.values, struct.values)
  end
end
