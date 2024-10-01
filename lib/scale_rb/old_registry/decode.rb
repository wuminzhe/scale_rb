# frozen_string_literal: true

require_relative '../codec_utils'

# rubocop:disable all
module ScaleRb
  module OldRegistry
    module Decode
      extend TypeEnforcer
      include Types

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

    end
  end
end
