# frozen_string_literal: true

require_relative '../codec_utils'

# rubocop:disable all
module ScaleRb
  module OldRegistry
    module Encode
      extend TypeEnforcer
      include Types

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

      # % encode_boolean :: Boolean -> U8Array
      def encode_boolean(value)
        return [0x00] if value == false
        return [0x01] if value == true

        raise InvalidValueError, "type: Bool, value: #{value.inspect}"
      end

      # % encode_string :: String -> U8Array
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

      # % encode_uint :: `U${Integer}` -> Any -> U8Array
      def encode_uint(type, value)
        raise InvalidValueError, "type: #{type}, value: #{value.inspect}" unless value.is_a?(Integer)

        bit_length = type[1..].to_i
        Utils.int_to_u8a(value, bit_length).reverse
      end

      # % encode_int :: `I${Integer}` -> Any -> U8Array
      def encode_int(type, value)
        raise NotImplemented, 'encode_int'
        # raise InvalidValueError, "type: #{type}, value: #{value.inspect}" unless value.is_a?(Integer)
        #
        # bit_length = type[1..].to_i
        # Utils.int_to_u8a(value, bit_length).reverse
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

      def _encode_types(types, values, registry = {})
        raise LengthNotEqualErr, "types: #{types}, values: #{values.inspect}" if types.length != values.length

        types.each_with_index.reduce([]) do |memo, (type, i)|
          memo + encode(type, values[i], registry)
        end
      end

    end
  end
end
