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
      # registry:
      #   [
      #     {
      #       id: type_id,
      #       path: [...],
      #       params: [...],
      #       def: {
      #         primitive: 'u8' | array: {} | ...
      #       }
      #     },
      #     {
      #       id: type_id,
      #       ...
      #     }
      #     ...
      #   ]
      def decode(id, bytes, registry)
        type = registry[id]
        raise TypeNotFound, "id: #{id}" if type.nil?

        bytes = ScaleRb::Utils.hex_to_u8a(bytes) if bytes.is_a?(::String)

        # type_def = type._get(:type, :def)
        case type.kind
        when 'Primitive' then decode_primitive(type, bytes)
        end

        return decode_primitive(type_def, bytes) if Utils.keys?(type_def, :primitive)
        return decode_compact(bytes) if Utils.keys?(type_def, :compact)
        return decode_array(type_def._get(:array), bytes, registry) if Utils.keys?(type_def, :array)
        return decode_sequence(type_def._get(:sequence), bytes, registry) if Utils.keys?(type_def, :sequence)
        return decode_tuple(type_def._get(:tuple), bytes, registry) if Utils.keys?(type_def, :tuple)
        return decode_composite(type_def._get(:composite), bytes, registry) if Utils.keys?(type_def, :composite)
        return decode_variant(type_def._get(:variant), bytes, registry) if Utils.keys?(type_def, :variant)

        raise TypeNotImplemented, "id: #{id}"
      end

      # Uint, Str, Bool
      # Int, Bytes ?
      def decode_primitive(type_def, bytes)
        primitive = type_def._get(:primitive)
        return ScaleRb.decode_uint(primitive, bytes) if ScaleRb.uint?(primitive)
        return ScaleRb.decode_string(bytes) if ScaleRb.string?(primitive)

        ScaleRb.decode_boolean(bytes) if ScaleRb.boolean?(primitive)
        # return ScaleRb.decode_int(primitive, bytes) if int?(primitive)
        # return ScaleRb.decode_bytes(bytes) if bytes?(primitive)
      end

      def decode_compact(bytes)
        ScaleRb.decode_compact(bytes)
      end

      def decode_array(array_type, bytes, registry)
        len = array_type._get(:len)
        inner_type_id = array_type._get(:type)

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

      def _u8?(type_id, registry)
        type = registry[type_id]
        raise TypeNotFound, "id: #{type_id}" if type.nil?

        type._get(:type, :def)._get(:primitive)&.downcase == 'u8'
      end

      def decode_sequence(sequence_type, bytes, registry)
        len, remaining_bytes = decode_compact(bytes)
        inner_type_id = sequence_type._get(:type)
        _decode_types([inner_type_id] * len, remaining_bytes, registry)
      end

      def decode_tuple(tuple_type, bytes, registry)
        _decode_types(tuple_type, bytes, registry)
      end

      # {
      #   name: value,
      #   ...
      # }
      def decode_composite(composite_type, bytes, registry)
        fields = composite_type._get(:fields)

        # reduce composite level when composite only has one field without name
        if fields.length == 1 && fields.first._get(:name).nil?
          decode(fields.first._get(:type), bytes, registry)
        else
          type_name_list = fields.map { |f| f._get(:name) }
          type_id_list = fields.map { |f| f._get(:type) }

          type_value_list, remaining_bytes = _decode_types(type_id_list, bytes, registry)
          [
            if type_name_list.all?(&:nil?)
              type_value_list
            else
              [type_name_list.map(&:to_sym), type_value_list].transpose.to_h
            end,
            remaining_bytes
          ]
        end
      end

      def decode_variant(variant_type, bytes, registry)
        variants = variant_type._get(:variants)

        index = bytes[0].to_i # TODO: check
        item = variants.find { |v| v._get(:index) == index } # item is an composite

        raise VariantIndexOutOfRange, "type: #{variant_type}, index: #{index}, bytes: #{bytes}" if item.nil?

        item_name = item._get(:name)
        item_fields = item._get(:fields)
        if item_fields.empty?
          [item_name, bytes[1..]]
        else
          item_value, remaining_bytes = decode_composite(item, bytes[1..], registry)
          [{ item_name.to_sym => item_value }, remaining_bytes]
        end
      end

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
