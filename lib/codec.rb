# frozen_string_literal: true

module ScaleRb
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
end

# Helper functions
# TODO: set, bitvec
module ScaleRb
  class << self
    #########################################
    # type definition check functions
    #########################################
    def type_def?(type)
      return true if type.is_a?(Hash)
      return false unless type.is_a?(String)

      %w[bytes boolean string compact int uint option array vec tuple].any? do |t|
        send("#{t}?", type)
      end
    end

    def bytes?(type) = type.casecmp('bytes').zero?
    def boolean?(type) = %w[bool boolean].include?(type.downcase)
    def string?(type) = %w[str string text type].include?(type.downcase)
    def compact?(type) = type.casecmp('compact').zero? || type.match?(/\Acompact<.+>\z/i)
    def int?(type) = type.match?(/\Ai(8|16|32|64|128|256|512)\z/i)
    def uint?(type) = type.match?(/\Au(8|16|32|64|128|256|512)\z/i)
    def option?(type) = type.match?(/\Aoption<.+>\z/i)
    def array?(type) = type.match?(/\A\[.+\]\z/)
    def vec?(type) = type.match?(/\Avec<.+>\z/i)
    def tuple?(type) = type.match?(/\A\(.+\)\z/)
    def struct?(type) = type.is_a?(Hash)
    def enum?(type) = type.is_a?(Hash) && type.key?(:_enum)

    #########################################
    # type string parsing functions
    #########################################
    def parse_option(type) = type.[](/\Aoption<(.+)>\z/i, 1)

    def parse_array(type)
      type.match(/\A\[\s*(.+?)\s*;\s*(\d+)\s*\]\z/)&.yield_self do |m|
        [m[1], m[2].to_i]
      end || raise(ScaleRb::TypeParseError, type)
    end

    def parse_vec(type) = type.[](/\Avec<(.+)>\z/i, 1)
    def parse_tuple(type) = type[/\A\(\s*(.+)\s*\)\z/, 1].split(',').map(&:strip)

    #########################################
    # type registry functions
    #########################################
    def _get_final_type_from_registry(registry, type)
      raise "Wrong lookup type #{type.class}" unless type.is_a?(String) || type.is_a?(Hash)
      return if type.is_a?(Hash)

      mapped = registry._get(type)
      return if mapped.nil?
      return mapped if type_def?(mapped)

      _get_final_type_from_registry(registry, mapped)
    end

    def _decode_types(types, bytes, registry)
      remaining_bytes = bytes
      values = types.map do |type|
        value, remaining_bytes = decode(type, remaining_bytes, registry)
        value
      end
      [values, remaining_bytes]
    end

    def _do_decode_compact(bytes)
      case bytes[0] & 3
      when 0 then [bytes[0] >> 2, bytes[1..]]
      when 1 then [Utils.u8a_to_uint(bytes[0..1].reverse) >> 2, bytes[2..]]
      when 2 then [Utils.u8a_to_uint(bytes[0..3].reverse) >> 2, bytes[4..]]
      when 3
        length = 4 + (bytes[0] >> 2)
        [Utils.u8a_to_uint(bytes[1..length].reverse), bytes[length + 1..]]
      else
        raise Unreachable, 'type: Compact'
      end
    end

    def _encode_types(types, values, registry = {})
      raise LengthNotEqualErr, "types: #{types}, values: #{values.inspect}" if types.length != values.length

      types.each_with_index.reduce([]) do |memo, (type, i)|
        memo + encode(type, values[i], registry)
      end
    end
  end
end

module ScaleRb
  # Decode
  class << self
    def decode(type, bytes, registry = {})
      bytes = ScaleRb::Utils.hex_to_u8a(bytes) if bytes.is_a?(::String)

      if type.is_a?(String)
        return decode_bytes(bytes) if bytes?(type) # Bytes
        return decode_boolean(bytes) if boolean?(type) # Boolean
        return decode_string(bytes) if string?(type) # String
        return decode_int(type, bytes) if int?(type) # i8, i16...
        return decode_uint(type, bytes) if uint?(type) # u8, u16...
        return decode_compact(bytes) if compact?(type) # Compact<>
        return decode_option(type, bytes, registry) if option?(type) # Option<>
        return decode_array(type, bytes, registry) if array?(type) # [u8; 3]
        return decode_vec(type, bytes, registry) if vec?(type) # Vec<u8>
        return decode_tuple(type, bytes, registry) if tuple?(type) # (u8, u8)

        # search the type from registry if not the types above
        registry_type = _get_final_type_from_registry(registry, type)
        return decode(registry_type, bytes, registry) if registry_type
      elsif type.is_a?(Hash)
        return decode_enum(type, bytes, registry) if enum?(type)
        return decode_struct(type, bytes, registry) if struct?(type)
      end

      raise NotImplemented, "type: #{type.inspect}"
    end

    def decode_bytes(bytes)
      length, remaining_bytes = _do_decode_compact(bytes)
      [Utils.u8a_to_hex(remaining_bytes[0...length]), remaining_bytes[length..]]
    end

    # % decode_boolean :: U8Array -> (Boolean, U8Array)
    def decode_boolean(bytes)
      value = case bytes[0]
              when 0x00 then false
              when 0x01 then true
              else raise InvalidBytesError, 'type: Boolean'
              end
      [value, bytes[1..]]
    end

    def decode_string(bytes)
      length, remaining_bytes = _do_decode_compact(bytes)
      raise NotEnoughBytesError, 'type: String' if remaining_bytes.length < length

      [Utils.u8a_to_utf8(remaining_bytes[0...length]), remaining_bytes[length..]]
    end

    def decode_int(type, bytes)
      bit_length = type[1..].to_i
      byte_length = bit_length / 8
      raise NotEnoughBytesError, "type: #{type}" if bytes.length < byte_length

      value = Utils.u8a_to_int(bytes[0...byte_length].reverse, bit_length)
      # debug 'value', value
      [
        value,
        bytes[byte_length..]
      ]
    end

    def decode_uint(type_def, bytes)
      bit_length = type_def[1..].to_i
      byte_length = bit_length / 8
      raise NotEnoughBytesError, "type: #{type_def}" if bytes.length < byte_length

      value = Utils.u8a_to_uint(bytes[0...byte_length].reverse)
      # debug 'value', value
      [
        value,
        bytes[byte_length..]
      ]
    end

    # % decode_compact :: U8Array -> (Any, U8Array)
    def decode_compact(bytes)
      _do_decode_compact(bytes)
      # debug 'value', result[0]
    end

    def decode_option(type_def, bytes, registry = {})
      inner_type = parse_option(type_def)

      return [nil, bytes[1..]] if bytes[0] == 0x00
      return decode(inner_type, bytes[1..], registry) if bytes[0] == 0x01

      raise InvalidBytesError, "type: #{type_def}"
    end

    def decode_array(type_def, bytes, registry = {})
      inner_type, length = parse_array(type_def)
      _decode_types([inner_type] * length, bytes, registry)
    end

    def decode_vec(type_def, bytes, registry = {})
      inner_type = parse_vec(type_def)
      length, remaining_bytes = _do_decode_compact(bytes)
      # debug 'length', length
      _decode_types([inner_type] * length, remaining_bytes, registry)
    end

    def decode_tuple(type_def, bytes, registry = {})
      inner_types = parse_tuple(type_def)
      _decode_types(inner_types, bytes, registry)
    end

    # TODO: custom index?
    # {
    #   _enum: {
    #     name1: type1,
    #     name2: type2
    #   }
    # }
    # or
    # {
    #   _enum: ['name1', 'name2']
    # }
    def decode_enum(type_def, bytes, registry = {})
      index = bytes[0]

      items = type_def[:_enum]
      raise IndexOutOfRangeError, "type: #{type_def}" if index > items.length - 1

      item = items.to_a[index] # 'name' or [:name, inner_type]
      # debug 'value', item.inspect
      return [item, bytes[1..]] if item.instance_of?(String)

      value, remaining_bytes = decode(item[1], bytes[1..], registry)
      [
        { item[0].to_sym => value },
        remaining_bytes
      ]
    end

    def decode_struct(struct, bytes, registry = {})
      values, remaining_bytes = _decode_types(struct.values, bytes, registry)
      [
        [struct.keys, values].transpose.to_h,
        remaining_bytes
      ]
    end
  end

  # Encode
  class << self
    def encode(type, value, registry = {})
      if type.instance_of?(String)
        return encode_bytes(value) if bytes?(type)
        return encode_boolean(value) if boolean?(type)
        return encode_string(value) if string?(type)
        return encode_compact(value) if compact?(type)
        return encode_uint(type, value) if uint?(type)
        return encode_option(type, value, registry) if option?(type)
        return encode_array(type, value, registry) if array?(type)
        return encode_vec(type, value, registry) if vec?(type)
        return encode_tuple(type, value, registry) if tuple?(type)

        registry_type = _get_final_type_from_registry(registry, type)
        return encode(registry_type, value, registry) if registry_type
      elsif type.instance_of?(Hash)
        return encode_enum(type, value, registry) if enum?(type)
        return encode_struct(type, value, registry) if struct?(type)
      end

      raise NotImplemented, "type: #{type}, value: #{value.inspect}"
    end

    def encode_bytes(value)
      encode_compact(value.length) + value
    end

    def encode_boolean(value)
      return [0x00] if value == false
      return [0x01] if value == true

      raise InvalidValueError, "type: Boolean, value: #{value.inspect}"
    end

    def encode_string(string)
      body = string.unpack('C*')
      encode_compact(body.length) + body
    end

    def encode_compact(value)
      return [value << 2] if value.between?(0, 63)
      return Utils.int_to_u8a(((value << 2) + 1)).reverse if value < 2**14
      return Utils.int_to_u8a(((value << 2) + 2)).reverse if value < 2**30

      bytes = Utils.int_to_u8a(value).reverse
      [(((bytes.length - 4) << 2) + 3)] + bytes
    end

    def encode_uint(type, value)
      raise InvalidValueError, "type: #{type}, value: #{value.inspect}" unless value.is_a?(Integer)

      bit_length = type[1..].to_i
      Utils.int_to_u8a(value, bit_length).reverse
    end

    def encode_option(type, value, registry = {})
      return [0x00] if value.nil?

      inner_type =  parse_option(type)
      [0x01] + encode(inner_type, value, registry)
    end

    def encode_array(type, array, registry = {})
      inner_type, length = parse_array(type)
      raise LengthNotEqualErr, "type: #{type}, value: #{array.inspect}" if length != array.length

      _encode_types([inner_type] * length, array, registry)
    end

    def encode_vec(type, array, registry = {})
      inner_type = parse_vec(type)
      encode_compact(array.length) + _encode_types([inner_type] * array.length, array, registry)
    end

    def encode_tuple(tuple_type, tuple, registry = {})
      inner_types = parse_tuple(tuple_type)
      _encode_types(inner_types, tuple, registry)
    end

    def encode_enum(enum_type, enum, registry = {})
      key = enum.keys.first
      value = enum.values.first
      value_type = enum_type[:_enum][key]
      index = enum_type[:_enum].keys.index(key)
      encode_uint('u8', index) + encode(value_type, value, registry)
    end

    def encode_struct(struct_type, struct, registry = {})
      _encode_types(struct_type.values, struct.values, registry)
    end
  end
end
