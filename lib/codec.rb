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

# TODO: set, bitvec
module ScaleRb
  class << self
    def type_def?(type)
      type.instance_of?(String) && (
        bytes?(type) ||
        boolean?(type) ||
        string?(type) ||
        compact?(type) ||
        int?(type) ||
        uint?(type) ||
        option?(type) ||
        array?(type) ||
        vec?(type) ||
        tuple?(type)
      ) ||
        type.instance_of?(Hash)
    end

    def bytes?(type)
      type.downcase == 'bytes'
    end

    def boolean?(type)
      type.downcase == 'bool' || type.downcase == 'boolean'
    end

    def string?(type)
      type.downcase == 'str' || type.downcase == 'string' || type.downcase == 'text' || type.downcase == 'type'
    end

    def compact?(type)
      type.downcase == 'compact' ||
        (type[0..7].downcase == 'compact<' && type[-1] == '>')
    end

    def int?(type)
      type[0].downcase == 'i' && type[1..] =~ /\A(8|16|32|64|128|256|512)\z/
    end

    def uint?(type)
      type[0].downcase == 'u' && type[1..] =~ /\A(8|16|32|64|128|256|512)\z/
    end

    def option?(type)
      type[0..6].downcase == 'option<' && type[-1] == '>'
    end

    def array?(type)
      type[0] == '[' && type[-1] == ']'
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
  end
end

module ScaleRb
  class << self
    def parse_option(type)
      type.scan(/\A[O|o]ption<(.+)>\z/).first.first
    end

    def parse_array(type)
      scan_out = type.scan(/\A\[\s*(.+)\s*;\s*(\d+)\s*\]\z/)
      raise ScaleRb::TypeParseError, type if scan_out.empty?
      raise ScaleRb::TypeParseError, type if scan_out[0].length != 2

      inner_type = scan_out[0][0]
      length = scan_out[0][1].to_i
      [inner_type, length]
    end

    def parse_vec(type)
      type.scan(/\A[V|v]ec<(.+)>\z/).first.first
    end

    def parse_tuple(type)
      type.scan(/\A\(\s*(.+)\s*\)\z/)[0][0].split(',').map(&:strip)
    end
  end
end

# Helper functions
module ScaleRb
  class << self
    def _get_final_type_from_registry(registry, type)
      raise "Wrong lookup type #{type.class}" if !type.instance_of?(String) && !type.instance_of?(Hash)

      return if type.instance_of?(Hash)

      mapped = registry._get(type) # mapped: String(name, type_def) | Hash(type_def: struct, enum) | nil

      return if mapped.nil?
      return mapped if type_def?(mapped)

      _get_final_type_from_registry(registry, mapped)
    end

    def _decode_types(types, bytes, registry)
      _decode_each(types, bytes) do |type, remaining_bytes|
        decode(type, remaining_bytes, registry)
      end
    end

    def _decode_each(types, bytes, &decode)
      remaining_bytes = bytes
      values = types.map do |type|
        value, remaining_bytes = decode.call(type, remaining_bytes)
        value
      end
      [values, remaining_bytes]
    end

    def _do_decode_compact(bytes)
      case bytes[0] & 3
      when 0
        [bytes[0] >> 2, bytes[1..]]
      when 1
        [bytes[0..1]._flip._to_uint >> 2, bytes[2..]]
      when 2
        [bytes[0..3]._flip._to_uint >> 2, bytes[4..]]
      when 3
        length = 4 + (bytes[0] >> 2)
        [bytes[1..length]._flip._to_uint, bytes[length + 1..]]
      else
        raise Unreachable, 'type: Compact'
      end
    end

    def _encode_each(types, values, &encode)
      _encode_each_without_merge(types, values, &encode).flatten
    end

    def _encode_each_without_merge(types, values, &encode)
      raise LengthNotEqualErr, "types: #{types}, values: #{values.inspect}" if types.length != values.length

      types.map.with_index do |type, i|
        encode.call(type, values[i])
      end
    end

    def _encode_types(types, values, registry = {})
      _encode_each(types, values) do |type, value|
        encode(type, value, registry)
      end
    end

    def _encode_each_with_hashers(types, values, hashers, &encode)
      if !hashers.nil? && hashers.length != types.length
        raise ScaleRb::LengthNotEqualErr, "types length: #{types.length}, hashers length: #{hashers.length}"
      end

      bytes_array = ScaleRb._encode_each_without_merge(types, values, &encode)
      bytes_array.each_with_index.reduce([]) do |memo, (bytes, i)|
        memo + Hasher.apply_hasher(hashers[i], bytes)
      end
    end
  end
end

module ScaleRb
  # Decode
  class << self
    def decode(type, bytes, registry = {})
      # logger.debug '--------------------------------------------------'
      # debug 'decoding type', type
      # debug 'bytes', bytes&.length

      if type.instance_of?(String)
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
      elsif type.instance_of?(Hash)
        return decode_enum(type, bytes, registry) if enum?(type)
        return decode_struct(type, bytes, registry) if struct?(type)
      end

      raise NotImplemented, "type: #{type.inspect}"
    end

    def decode_bytes(bytes)
      length, remaining_bytes = _do_decode_compact(bytes)
      value = remaining_bytes[0...length]._to_hex
      # debug 'length', length
      # debug 'value', value
      [
        value,
        remaining_bytes[length..]
      ]
    end

    def decode_boolean(bytes)
      value =
        if bytes[0] == 0x00
          false
        elsif bytes[0] == 0x01
          true
        else
          raise InvalidBytesError, 'type: Boolean'
        end
      # debug 'value', value
      [value, bytes[1..]]
    end

    def decode_string(bytes)
      length, remaining_bytes = _do_decode_compact(bytes)
      raise NotEnoughBytesError, 'type: String' if remaining_bytes.length < length

      value = remaining_bytes[0...length]._to_utf8
      # debug 'byte length', length
      # debug 'value', value.inspect
      [
        value,
        remaining_bytes[length..]
      ]
    end

    def decode_int(type, bytes)
      bit_length = type[1..].to_i
      byte_length = bit_length / 8
      raise NotEnoughBytesError, "type: #{type}" if bytes.length < byte_length

      value = bytes[0...byte_length]._flip._to_int(bit_length)
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

      value = bytes[0...byte_length]._flip._to_uint
      # debug 'value', value
      [
        value,
        bytes[byte_length..]
      ]
    end

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
      # logger.debug '--------------------------------------------------'
      # debug 'encoding type', type
      # debug 'value', value

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
      prefix = encode_compact(body.length)
      prefix + body
    end

    def encode_compact(value)
      return [value << 2] if (value >= 0) && (value < 64)
      return ((value << 2) + 1)._to_bytes._flip if value < 2**14
      return ((value << 2) + 2)._to_bytes._flip if value < 2**30

      bytes = value._to_bytes._flip
      [(((bytes.length - 4) << 2) + 3)] + bytes
    end

    def encode_uint(type, value)
      raise InvalidValueError, "type: #{type}, value: #{value.inspect}" unless value.instance_of?(Integer)

      bit_length = type[1..].to_i
      value._to_bytes(bit_length)._flip
    end

    def encode_option(type, value, registry = {})
      return [0x00] if value.nil?

      inner_type = type.scan(/\A[O|o]ption<(.+)>\z/).first.first
      [0x01] + encode(inner_type, value, registry)
    end

    def encode_array(type, array, registry = {})
      inner_type, length = parse_array(type)
      raise LengthNotEqualErr, "type: #{type}, value: #{array.inspect}" if length != array.length

      _encode_types([inner_type] * length, array, registry)
    end

    def encode_vec(type, array, registry = {})
      inner_type = type.scan(/\A[V|v]ec<(.+)>\z/).first.first
      length_bytes = encode_compact(array.length)
      length_bytes + _encode_types([inner_type] * array.length, array, registry)
    end

    def encode_tuple(tuple_type, tuple, registry = {})
      inner_types = tuple_type.scan(/\A\(\s*(.+)\s*\)\z/)[0][0].split(',').map(&:strip)
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
