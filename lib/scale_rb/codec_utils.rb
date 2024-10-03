# frozen_string_literal: true

module ScaleRb
  module CodecUtils
    module InternalDecodeUtils
      extend TypeEnforcer
      include Types

      sig :decode_uint, { type: String.constrained(format: /\AU\d+\z/), bytes: U8Array }, DecodeResult[UnsignedInteger]
      def decode_uint(type, bytes)
        bit_length = type[1..].to_i
        byte_length = bit_length / 8
        raise Codec::NotEnoughBytesError, "type: #{type}" if bytes.length < byte_length

        value = Utils.u8a_to_uint(bytes[0...byte_length].reverse)
        # debug 'value', value
        [
          value,
          bytes[byte_length..]
        ]
      end

      sig :decode_int, { type: String.constrained(format: /\AI\d+\z/), bytes: U8Array }, DecodeResult[Integer]
      def decode_int(type, bytes)
        bit_length = type[1..].to_i
        byte_length = bit_length / 8
        raise Codec::NotEnoughBytesError, "type: #{type}" if bytes.length < byte_length

        value = Utils.u8a_to_int(bytes[0...byte_length].reverse, bit_length)
        # debug 'value', value
        [
          value,
          bytes[byte_length..]
        ]
      end

      sig :decode_str, { bytes: U8Array }, DecodeResult[String]
      def decode_str(bytes)
        length, remaining_bytes = _do_decode_compact(bytes)
        raise Codec::NotEnoughBytesError, 'type: String' if remaining_bytes.length < length

        [Utils.u8a_to_utf8(remaining_bytes[0...length]), remaining_bytes[length..]]
      end

      sig :decode_boolean, { bytes: U8Array }, DecodeResult[Bool]
      def decode_boolean(bytes)
        value = case bytes[0]
                when 0x00 then false
                when 0x01 then true
                else raise Codec::InvalidBytesError, 'type: Boolean'
                end
        [value, bytes[1..]]
      end

      # TODO: inner type decoding
      sig :decode_compact, { bytes: U8Array }, DecodeResult[UnsignedInteger]
      def decode_compact(bytes)
        _do_decode_compact(bytes)
      end


      # % encode_uint :: `U${Integer}` -> Any -> U8Array
      def encode_uint(type, value)
        raise InvalidValueError, "type: #{type}, value: #{value.inspect}" unless value.is_a?(::Integer)

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

      # % encode_str :: String -> U8Array
      def encode_str(string)
        body = string.unpack('C*')
        encode_compact(body.length) + body
      end

      # % encode_boolean :: Boolean -> U8Array
      def encode_boolean(value)
        return [0x00] if value == false
        return [0x01] if value == true

        raise InvalidValueError, "type: Bool, value: #{value.inspect}"
      end

      def encode_compact(value)
        return [value << 2] if value.between?(0, 63)
        return Utils.int_to_u8a(((value << 2) + 1)).reverse if value < 2**14
        return Utils.int_to_u8a(((value << 2) + 2)).reverse if value < 2**30

        bytes = Utils.int_to_u8a(value).reverse
        [(((bytes.length - 4) << 2) + 3)] + bytes
      end

      private

      def _do_decode_compact(bytes)
        case bytes[0] & 3
        when 0 then [bytes[0] >> 2, bytes[1..]]
        when 1 then [Utils.u8a_to_uint(bytes[0..1].reverse) >> 2, bytes[2..]]
        when 2 then [Utils.u8a_to_uint(bytes[0..3].reverse) >> 2, bytes[4..]]
        when 3
          length = 4 + (bytes[0] >> 2)
          [Utils.u8a_to_uint(bytes[1..length].reverse), bytes[length + 1..]]
        else
          raise Codec::Unreachable, 'type: Compact'
        end
      end
    end

    extend InternalDecodeUtils
  end
end
