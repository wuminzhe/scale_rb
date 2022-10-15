# frozen_string_literal: true

module PortableCodec
  class Error < StandardError; end
  class TypeNotFound < Error; end
  class TypeNotImplemented < Error; end
  class CompositeInvalidValue < Error; end
  class ArrayLengthNotEqual < Error; end
  class VariantItemNotFound < Error; end
  class VariantIndexOutOfRange < Error; end
  class VariantInvalidValue < Error; end

  class << self
    # registry:
    #   {
    #     0 => {
    #       path: [...],
    #       params: [...],
    #       def: {
    #         primitive: 'u8' | array: {} | ...
    #       }
    #     },
    #     1 => {
    #       ...
    #     }
    #   }
    def decode(id, bytes, registry)
      type = registry[id]
      raise TypeNotFound, "id: #{id}" if type.nil?

      _path = type._get(:path)
      _params = type._get(:params)
      type_def = type._get(:def)

      return decode_primitive(type_def, bytes) if type_def._key?(:primitive)
      return decode_compact(bytes) if type_def._key?(:compact)
      return decode_array(type_def._get(:array), bytes, registry) if type_def._key?(:array)
      return decode_sequence(type_def._get(:sequence), bytes, registry) if type_def._key?(:sequence)
      return decode_tuple(type_def._get(:tuple), bytes, registry) if type_def._key?(:tuple)
      return decode_composite(type_def._get(:composite), bytes, registry) if type_def._key?(:composite)
      return decode_variant(type_def._get(:variant), bytes, registry) if type_def._key?(:variant)

      raise TypeNotImplemented, "id: #{id}"
    end

    # Uint, Str, Bool
    # Int, Bytes ?
    def decode_primitive(type_def, bytes)
      primitive = type_def._get(:primitive)
      return ScaleRb.decode_uint(primitive, bytes) if ScaleRb.uint?(primitive)
      return ScaleRb.decode_string(bytes) if ScaleRb.string?(primitive)
      return ScaleRb.decode_boolean(bytes) if ScaleRb.boolean?(primitive)
      # return ScaleRb.decode_int(primitive, bytes) if int?(primitive)
      # return ScaleRb.decode_bytes(bytes) if bytes?(primitive)
    end

    def decode_compact(bytes)
      ScaleRb.decode_compact(bytes)
    end

    def decode_array(array_type, bytes, registry)
      len = array_type._get(:len)
      inner_type_id = array_type._get(:type)
      _decode_types([inner_type_id] * len, bytes, registry)
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

      index = bytes[0]
      if index > (variants.length - 1)
        raise VariantIndexOutOfRange,
              "type: #{variant_type}, index: #{index}, bytes: #{bytes}"
      end

      item_variant = variants.find { |v| v._get(:index) == index }
      item_name = item_variant._get(:name)
      item, remaining_bytes = decode_composite(item_variant, bytes[1..], registry)

      [
        item.empty? ? item_name : { item_name.to_sym => item },
        remaining_bytes
      ]
    end

    def _decode_types(ids, bytes, registry = {})
      ScaleRb._decode_each(ids, bytes) do |id, remaining_bytes|
        decode(id, remaining_bytes, registry)
      end
    end

    def encode_with_hasher(value, type_id, registry, hasher)
      value_bytes = encode(type_id, value, registry)
      Hasher.apply_hasher(hasher, value_bytes)
    end

    def encode(id, value, registry)
      type = registry[id]
      raise TypeNotFound, "id: #{id}" if type.nil?

      type_def = type._get(:def)

      return encode_primitive(type_def, value) if type_def._key?(:primitive)
      return encode_compact(value) if type_def._key?(:compact)
      return encode_array(type_def._get(:array), value, registry) if type_def._key?(:array)
      return encode_sequence(type_def._get(:sequence), value, registry) if type_def._key?(:sequence)
      return encode_tuple(type_def._get(:tuple), value, registry) if type_def._key?(:tuple)
      return encode_composite(type_def._get(:composite), value, registry) if type_def._key?(:composite)
      return encode_variant(type_def._get(:variant), value, registry) if type_def._key?(:variant)

      raise TypeNotImplemented, "id: #{id}"
    end

    def encode_primitive(type_def, value)
      primitive = type_def._get(:primitive)
      return ScaleRb.encode_uint(primitive, value) if ScaleRb.uint?(primitive)
      return ScaleRb.encode_string(value) if ScaleRb.string?(primitive)
      return ScaleRb.encode_boolean(value) if ScaleRb.boolean?(primitive)
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
      length_bytes + _encode_types([inner_type_id] * array.length, value, registry)
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

      variant = variants.find { |var| var._get(:name) == name }
      raise VariantItemNotFound, "type: #{variant_type}, name: #{name}" if variant.nil?
      raise VariantInvalidValue, "type: #{variant_type}, v: #{v}" if variant._get(:fields).length != v.length

      ScaleRb.encode_uint('u8', variant._get(:index)) + encode_composite(variant, v, registry)
    end

    def _encode_types(ids, values, registry)
      ScaleRb._encode_each(ids, values) do |id, value|
        encode(id, value, registry)
      end
    end

    def _encode_types_with_hashers(ids, values, registry, hashers)
      ScaleRb._encode_each_with_hashers(ids, values, hashers) do |id, value|
        encode(id, value, registry)
      end
    end
  end
end
