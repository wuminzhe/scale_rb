# frozen_string_literal: true

module ScaleRb
  module PortableCodec
    class Error < StandardError; end
    class TypeNotFound < Error; end
    class TypeNotImplemented < Error; end
    class CompositeInvalidValue < Error; end
    class ArrayLengthNotEqual < Error; end
    class VariantItemNotFound < Error; end
    class VariantIndexOutOfRange < Error; end
    class VariantInvalidValue < Error; end
    class VariantFieldsLengthNotMatch < Error; end

    class << self
      def u256(value)
        bytes = ScaleRb.encode('u256', value)
        bytes.each_slice(8).map do |slice|
          ScaleRb.decode('u64', slice).first
        end
      end
    end

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

        # check if the type of inner_type_id is a u8
        if _u8?(inner_type_id, registry)
          [
            Utils.u8a_to_hex(bytes[0...len]),
            bytes[len..]
          ]
        else
          _decode_types([inner_type_id] * len, bytes, registry)
        end
      end

      # % _u8? :: Ti -> Array<PortableType> -> Bool
      def _u8?(type_id, registry)
        type = registry[type_id]
        raise TypeNotFound, "id: #{type_id}" if type.nil?

        type.is_a?(ScaleRb::PrimitiveType) && type.primitive == 'U8'
      end

      # % decode_sequence :: SequenceType -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def decode_sequence(sequence_type, bytes, registry)
        len, remaining_bytes = decode_compact(bytes)
        _decode_types([sequence_type.type] * len, remaining_bytes, registry)
      end

      # % decode_tuple :: TupleType -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def decode_tuple(tuple_type, bytes, registry)
        _decode_types(tuple_type, bytes, registry)
      end

      # % decode_struct :: StructType -> U8Array -> Array<PortableType> -> (Hash<Symbol, Any>, U8Array)
      def decode_struct(struct_type, bytes, registry)
        fields = struct_type.fields

        names = fields.map { |f| f.name.to_sym }
        type_ids = fields.map(&:type)

        values, remaining_bytes = _decode_types(type_ids, bytes, registry)
        [
          [names, values].transpose.to_h
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
        when ScaleRb::SimpleVariant then [variant.name, bytes[1..]]
        when ScaleRb::TupleVariant then decode_tuple(variant.tuple, bytes[1..], registry)
        when ScaleRb::StructVariant then decode_struct(variant.struct, bytes[1..], registry)
        else raise "Unreachable"
        end
      end

      # % _decode_types :: Array<Ti> -> U8Array -> Array<PortableType> -> (Array<Any>, U8Array)
      def _decode_types(ids, bytes, registry = {})
        remaining_bytes = bytes
        values = ids.map do |id|
          value, remaining_bytes = decode(id, remaining_bytes, registry)
          value
        end
        [values, remaining_bytes]
      end

      def encode_with_hasher(value, type_id, registry, hasher)
        value_bytes = encode(type_id, value, registry)
        Hasher.apply_hasher(hasher, value_bytes)
      end

      def encode(id, value, registry)
        type = registry[id]
        raise TypeNotFound, "id: #{id}" if type.nil?

        type_def = type._get(:type, :def)

        return encode_primitive(type_def, value) if Utils.keys?(type_def, :primitive)
        return encode_compact(value) if Utils.keys?(type_def, :compact)
        return encode_array(type_def._get(:array), value, registry) if Utils.keys?(type_def, :array)
        return encode_sequence(type_def._get(:sequence), value, registry) if Utils.keys?(type_def, :sequence)
        return encode_tuple(type_def._get(:tuple), value, registry) if Utils.keys?(type_def, :tuple)
        return encode_composite(type_def._get(:composite), value, registry) if Utils.keys?(type_def, :composite)
        return encode_variant(type_def._get(:variant), value, registry) if Utils.keys?(type_def, :variant)

        raise TypeNotImplemented, "id: #{id}"
      end

      def encode_primitive(type_def, value)
        primitive = type_def._get(:primitive)
        return ScaleRb.encode_uint(primitive, value) if ScaleRb.uint?(primitive)
        return ScaleRb.encode_string(value) if ScaleRb.string?(primitive)

        ScaleRb.encode_boolean(value) if ScaleRb.boolean?(primitive)
      end

      def encode_compact(value)
        ScaleRb.encode_compact(value)
      end

      def encode_array(array_type, value, registry)
        length = array_type._get(:len)
        inner_type_id = array_type._get(:type)
        raise ArrayLengthNotEqual, "type: #{array_type}, value: #{value.inspect}" if length != value.length

        _encode_types([inner_type_id] * length, value, registry)
      end

      def encode_sequence(sequence_type, value, registry)
        inner_type_id = sequence_type._get(:type)
        length_bytes = encode_compact(value.length)
        length_bytes + _encode_types([inner_type_id] * value.length, value, registry)
      end

      # tuple_type: [type_id1, type_id2, ...]
      def encode_tuple(tuple_type, value, registry)
        _encode_types(tuple_type, value, registry)
      end

      # value:
      #   {
      #     name1: value1,
      #     name2: value2,
      #     ...
      #   }
      #   or
      #   [value1, value2, ...]
      def encode_composite(composite_type, value, registry)
        fields = composite_type._get(:fields)
        # reduce composite level when composite only has one field without name
        if fields.length == 1 && fields.first._get(:name).nil?
          encode(fields.first._get(:type), value, registry)
        else
          values =
            if value.instance_of?(Hash)
              value.values
            elsif value.instance_of?(Array)
              value
            else
              raise CompositeInvalidValue, "value: #{value}, only hash and array"
            end

          type_id_list = fields.map { |f| f._get(:type) }
          _encode_types(type_id_list, values, registry)
        end
      end

      # value:
      # {
      #   name: v(Hash)
      # }
      # or
      # the_value(String)
      def encode_variant(variant_type, value, registry)
        variants = variant_type._get(:variants)

        name, v = # v: item inner value
          if value.instance_of?(Hash)
            [value.keys.first.to_s, value.values.first]
          elsif value.instance_of?(String)
            [value, {}]
          else
            raise VariantInvalidValue, "type: #{variant_type}, value: #{value}"
          end

        item = variants.find { |var| var._get(:name) == name }
        raise VariantItemNotFound, "type: #{variant_type}, name: #{name}" if item.nil?

        # if the variant item has more than one field, the value must be a hash with the same length.
        # if the variant item has only one field, that means the field is a type id point to a composite. TODO: check the type's fields length
        if item._get(:fields).length > 1 && item._get(:fields).length != v.length
          raise VariantFieldsLengthNotMatch,
                "type: #{variant_type}, \nvalue: #{v}"
        end

        ScaleRb.encode_uint('u8', item._get(:index)) + encode_composite(item, v, registry)
      end

      def _encode_types(ids, values, registry)
        raise LengthNotEqualErr, "ids: #{ids}, values: #{values.inspect}" if ids.length != values.length

        ids.each_with_index.reduce([]) do |memo, (id, i)|
          memo + encode(id, values[i], registry)
        end
      end

      def _encode_types_with_hashers(ids, values, registry, hashers)
        if !hashers.nil? && hashers.length != ids.length
          raise ScaleRb::LengthNotEqualErr, "ids length: #{ids.length}, hashers length: #{hashers.length}"
        end

        ids
          .map.with_index { |id, i| encode(id, values[i], registry) }
          .each_with_index.reduce([]) do |memo, (bytes, i)|
            memo + Hasher.apply_hasher(hashers[i], bytes)
          end
      end
    end
  end
end
