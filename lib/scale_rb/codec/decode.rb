# frozen_string_literal: true

module ScaleRb
  module Codec
    class << self
      # % decode :: Ti -> U8Array | Hex -> Array<PortableType> -> (Any, U8Array)
      def decode(id, bytes, registry)
        type = registry[id]
        raise TypeNotFound, "id: #{id}" if type.nil?

        # convert hex string to u8 array
        bytes = ScaleRb::Utils.hex_to_u8a(bytes) if bytes.is_a?(::String)

        case type
        when ScaleRb::PrimitiveType then decode_primitive(type, bytes)
        when ScaleRb::CompactType then decode_compact(bytes)
        when ScaleRb::ArrayType then decode_array(type, bytes, registry)
        when ScaleRb::SequenceType then decode_sequence(type, bytes, registry)
        when ScaleRb::TupleType then decode_tuple(type, bytes, registry)
        when ScaleRb::StructType then decode_struct(type, bytes, registry)
        when ScaleRb::UnitType then [[], bytes]
        when ScaleRb::VariantType then decode_variant(type, bytes, registry)
        else raise TypeNotImplemented, "id: #{id}, type: #{type}"
        end
      end

      # % decode_primitive :: PrimitiveType -> U8Array -> (Any, U8Array)
      def decode_primitive(type, bytes)
        primitive = type.primitive
        return ScaleRb.decode_uint(primitive, bytes) if primitive.start_with?('U')
        return ScaleRb.decode_int(primitive, bytes) if primitive.start_with?('I')
        return ScaleRb.decode_string(bytes) if type.primitive == 'Str'
        return ScaleRb.decode_boolean(bytes) if type.primitive == 'Bool'

        raise TypeNotImplemented, "primitive: #{primitive}"
      end

      # % decode_compact :: U8Array -> (Any, U8Array)
      def decode_compact(bytes)
        ScaleRb.decode_compact(bytes)
      end

      # % decode_array :: ArrayType -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def decode_array(type, bytes, registry)
        len = type.len
        inner_type_id = type.type

        # Note: if the decode value is a u8 array, convert it to a hex string.
        # This is to make the structure of the decoded result clear.
        if _u8?(inner_type_id, registry)
          [
            Utils.u8a_to_hex(bytes[0...len]),
            bytes[len..]
          ]
        else
          _decode_types([inner_type_id] * len, bytes, registry)
        end
      end

      # % decode_sequence :: SequenceType -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def decode_sequence(sequence_type, bytes, registry)
        len, remaining_bytes = decode_compact(bytes)
        _decode_types([sequence_type.type] * len, remaining_bytes, registry)
      end

      # % decode_tuple :: TupleType -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def decode_tuple(tuple_type, bytes, registry)
        type_ids = tuple_type.tuple

        # Note: If the tuple has only one element, decode that element directly.
        # This is to make the structure of the decoded result clear.
        if type_ids.length == 1
          decode(type_ids.first, bytes, registry)
        else
          _decode_types(type_ids, bytes, registry)
        end
      end

      # % decode_struct :: StructType -> U8Array -> Array<PortableType> -> (Hash<Symbol, Any>, U8Array)
      def decode_struct(struct_type, bytes, registry)
        fields = struct_type.fields

        names = fields.map { |f| f.name.to_sym }
        type_ids = fields.map(&:type)

        values, remaining_bytes = _decode_types(type_ids, bytes, registry)
        [
          [names, values].transpose.to_h,
          remaining_bytes
        ]
      end

      # % decode_variant :: VariantType -> U8Array -> Array<PortableType> -> (Any, U8Array)
      def decode_variant(variant_type, bytes, registry)
        # find the variant by the index
        index = bytes[0].to_i
        variant = variant_type.variants.find { |v| v.index == index }
        raise VariantIndexOutOfRange, "type: #{variant_type}, index: #{index}, bytes: #{bytes}" if variant.nil?

        # decode the variant
        case variant
        when ScaleRb::SimpleVariant
          [
            variant.name,
            bytes[1..]
          ]
        when ScaleRb::TupleVariant
          value, remainning_bytes = decode_tuple(variant.tuple, bytes[1..] , registry)
          [
            { variant.name.to_sym => value },
            remainning_bytes
          ]
        when ScaleRb::StructVariant then 
          value, remainning_bytes = decode_struct(variant.struct, bytes[1..], registry)
          [
            { variant.name.to_sym => value },
            remainning_bytes
          ]
        else raise "Unreachable"
        end
      end

      private

      # _u8? :: Ti -> Array<PortableType> -> Bool
      def _u8?(type_id, registry)
        type = registry[type_id]
        raise TypeNotFound, "id: #{type_id}" if type.nil?

        type.is_a?(ScaleRb::PrimitiveType) && type.primitive == 'U8'
      end

      # _decode_types :: Array<Ti> -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def _decode_types(ids, bytes, registry = {})
        remaining_bytes = bytes
        values = ids.map do |id|
          value, remaining_bytes = decode(id, remaining_bytes, registry)
          value
        end
        [values, remaining_bytes]
      end
    end
  end
end
