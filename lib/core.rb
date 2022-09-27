# frozen_string_literal: true

module ScaleRb2Core
  class << self
    def decode_bytes(bytes)
      length, remaining_bytes = _do_decode_compact(bytes)
      value = remaining_bytes[0...length].to_hex
      debug 'length', length
      debug 'value', value
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
          raise ScaleRb2::InvalidBytesError, 'type: Boolean'
        end
      debug 'value', value
      [value, bytes[1..]]
    end

    def decode_string(bytes)
      length, remaining_bytes = _do_decode_compact(bytes)
      raise ScaleRb2::NotEnoughBytesError, 'type: String' if remaining_bytes.length < length

      value = remaining_bytes[0...length].to_utf8
      debug 'byte length', length
      debug 'value', value.inspect
      [
        value,
        remaining_bytes[length..]
      ]
    end

    def decode_int(bit_length, bytes)
      byte_length = bit_length / 8
      raise ScaleRb2::NotEnoughBytesError, "type: #{type_id}" if bytes.length < byte_length

      value = bytes[0...byte_length].flip.to_int(bit_length)
      debug 'value', value
      [
        value,
        bytes[byte_length..]
      ]
    end

    def decode_uint(bit_length, bytes)
      byte_length = bit_length / 8
      raise ScaleRb2::NotEnoughBytesError, "type: #{type_id}" if bytes.length < byte_length

      value = bytes[0...byte_length].flip.to_uint
      debug 'value', value
      [
        value,
        bytes[byte_length..]
      ]
    end

    def decode_compact(bytes)
      result = _do_decode_compact(bytes)
      debug 'value', result[0]
      result
    end

    def decode_option(inner_type_id, bytes, registry )
      return [nil, bytes[1..]] if bytes[0] == 0x00
      return decode(inner_type_id, bytes[1..], registry) if bytes[0] == 0x01

      raise InvalidBytesError, "type: Option<#{inner_type_id}>"
    end

    def decode_array(inner_type_id, length, bytes, registry)
      _decode_types([inner_type_id] * length, bytes, registry)
    end

    def decode_vec(inner_type_id, bytes, registry)
      length, remaining_bytes = _do_decode_compact(bytes)
      debug 'length', length
      _decode_types([inner_type_id] * length, remaining_bytes, registry)
    end

    def decode_tuple(inner_type_ids, bytes, registry)
      _decode_types(inner_type_ids, bytes, registry)
    end

    # TODO: custrom index
    # enum_type
    # {
    #   Int: 12,
    #   Hello: 123
    # }
    # or
    # ['Abc', 'Def']
    def decode_enum(enum_type, bytes, registry)
      index = bytes[0]
      raise IndexOutOfRangeError, "_enum: #{enum_type}" if index > enum_type.length - 1

      remaining_bytes = bytes[1..]
      if enum_type.instance_of?(Hash)
        key = enum_type.keys[index]
        type_id = enum_type.values[index]

        value, remaining_bytes = decode(type_id, remaining_bytes, registry)
        [
          { key => value },
          remaining_bytes
        ]
      elsif enum_type.instance_of?(Array)
        value = enum_type[index]
        debug 'value', value.inspect
        [
          value,
          remaining_bytes
        ]
      end
    end

    # stuct_type
    # {
    #   Int: 12,
    #   Hello: 123
    # }
    def decode_struct(struct_type, bytes, registry)
      values, remaining_bytes = _decode_types(struct_type.values, bytes, registry)
      [
        [struct_type.keys, values].transpose.to_h,
        remaining_bytes
      ]
    end
  end
    private

    def _do_decode_compact(bytes)
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
        raise ScaleRb2::Unreachable, 'type: Compact'
      end
    end

    def _decode_types(type_ids, bytes, registry)
      remaining_bytes = bytes
      values = type_ids.map do |type_id|
        value, remaining_bytes = decode(type_id, remaining_bytes, registry)
        value
      end
      [values, remaining_bytes]
    end
  end
end
