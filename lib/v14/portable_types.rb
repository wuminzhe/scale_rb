# frozen_string_literal: true

module PortableTypes
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
      return ScaleRb2.decode_uint(primitive, bytes) if uint?(primitive)
      return ScaleRb2.decode_string(bytes) if string?(primitive)
      return ScaleRb2.decode_boolean(bytes) if boolean?(primitive)
      # return ScaleRb2.decode_int(primitive, bytes) if int?(primitive)
      # return ScaleRb2.decode_bytes(bytes) if bytes?(primitive)
    end

    def decode_compact(bytes)
      ScaleRb2.decode_compact(bytes)
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
      if ids.empty?
        [[], bytes]
      else
        value, remaining_bytes = decode(ids.first, bytes, registry)
        value_list, remaining_bytes = _decode_types(ids[1..], remaining_bytes, registry)
        [[value] + value_list, remaining_bytes]
      end
    end

    def encode_with_hasher(value, type_id, registry, hasher)
      value_bytes = PortableTypes.encode(type_id, value, registry)
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
      return ScaleRb2.encode_uint(primitive, value) if uint?(primitive)
      return ScaleRb2.encode_string(value) if string?(primitive)
      return ScaleRb2.encode_boolean(value) if boolean?(primitive)
    end

    def encode_compact(value)
      ScaleRb2.encode_compact(value)
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
      values =
        if value.instance_of?(Hash)
          value.values
        elsif value.instance_of?(Array)
          value
        else
          raise CompositeInvalidValue, "value: #{value}, only hash and array"
        end

      fields = composite_type._get(:fields)
      type_id_list = fields.map { |f| f._get(:type) }
      _encode_types(type_id_list, values, registry)
    end

    # value:
    # {
    #   name: the_value(Hash)
    # }
    # or
    # the_value(String)
    def encode_variant(variant_type, value, registry)
      variants = variant_type._get(:variants)

      if value.instance_of?(Hash)
        name = value.keys.first.to_s
        the_value = value.values.first
      elsif value.instance_of?(String)
        name = value
        the_value = {}
      else
        raise VariantInvalidValue, "type: #{variant_type}, value: #{value}"
      end

      variant = variants.find { |v| v[:name] == name }
      raise VariantItemNotFound, "type: #{variant_type}, name: #{name}" if variant.nil?

      ScaleRb2.encode_uint('u8', variant._get(:index)) + encode_composite(variant, the_value, registry)
    end

    def _encode_types(ids, values, registry)
      _encode_types_without_merge(ids, values, registry).flatten
    end

    def _encode_types_with_hashers(values, type_ids, registry, hashers)
      if !hashers.nil? && hashers.length != type_ids.length
        raise ScaleRb2::LengthNotEqualErr, "type_ids length: #{type_ids.length}, hashers length: #{hashers.length}"
      end

      bytes_array = _encode_types_without_merge(type_ids, values, registry)
      bytes_array.each_with_index.reduce([]) do |memo, (bytes, i)|
        memo + Hasher.apply_hasher(hashers[i], bytes)
      end
    end

    # return: [value1_bytes, value2_bytes, ...]
    def _encode_types_without_merge(ids, values, registry)
      raise ScaleRb2::LengthNotEqualErr, "types: #{ids}, values: #{values.inspect}" if ids.length != values.length

      ids.map.with_index do |type_id, i|
        encode(type_id, values[i], registry)
      end
    end

  end
end
