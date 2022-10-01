# frozen_string_literal: true

module PortableTypes
  class Error < StandardError; end
  class TypeNotFound < Error; end

  class << self
    def decode(id, bytes, registry)
      type = registry[id]
      raise TypeNotFound, "id: #{id}" if type.nil?

      _path = type[:path]
      _params = type[:params]
      type_def = type[:def]

      return decode_primitive(type_def, bytes) if type_def.key?(:primitive)
      return decode_compact(bytes) if type_def.key?(:compact)
      return decode_array(type_def[:array], bytes, registry) if type_def.key?(:array)
      return decode_sequence(type_def[:sequence], bytes, registry) if type_def.key?(:sequence)
      return decode_tuple(type_def[:tuple], bytes, registry) if type_def.key?(:tuple)
      return decode_composite(type_def[:composite], bytes, registry) if type_def.key?(:composite)
      return decode_variant(type_def[:variant], bytes, registry) if type_def.key?(:variant)

      raise NotImplementedError, "id: #{id}"
    end

    # Uint, Str, Bool
    # Int, Bytes ?
    def decode_primitive(type_def, bytes)
      primitive = type_def[:primitive]
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
      len = array_type[:len]
      inner_type_id = array_type[:type]
      _decode_types([inner_type_id] * len, bytes, registry)
    end

    def decode_sequence(sequence_type, bytes, registry)
      len, remaining_bytes = decode_compact(bytes)
      inner_type_id = sequence_type[:type]
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
      fields = composite_type[:fields]

      type_name_list = fields.map { |f| f[:name] }
      type_id_list = fields.map { |f| f[:type] }

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
      variants = variant_type[:variants]

      index = bytes[0]
      raise ScaleRb2::IndexOutOfRangeError, "type: #{variant_type}, bytes: #{bytes}" if index > (variants.length - 1)

      item_variant = variants.find { |v| v[:index] == index }
      item_name = item_variant[:name]
      item, remaining_bytes = decode_composite(item_variant, bytes[1..], registry)

      [
        item.empty? ? item_name : { item_name.to_sym => item },
        remaining_bytes
      ]
    end

    def _decode_types(type_id_list, bytes, registry = {})
      if type_id_list.empty?
        [[], bytes]
      else
        value, remaining_bytes = decode(type_id_list.first, bytes, registry)
        value_list, remaining_bytes = _decode_types(type_id_list[1..], remaining_bytes, registry)
        [[value] + value_list, remaining_bytes]
      end
    end

    def encode(id, value, registry)
      type = registry[id]
      raise TypeNotFound, "id: #{id}" if type.nil?

      type_def = type[:def]

      return encode_primitive(type_def, value) if type_def.key?(:primitive)
      return encode_compact(value) if type_def.key?(:compact)
      return encode_array(id, type_def[:array], value, registry) if type_def.key?(:array)
      return encode_sequence(type_def[:sequence], value, registry) if type_def.key?(:sequence)
      return encode_tuple(type_def[:tuple], value, registry) if type_def.key?(:tuple)
      return encode_composite(type_def[:composite], value, registry) if type_def.key?(:composite)
      return encode_variant(id, type_def[:variant], value, registry) if type_def.key?(:variant)

      raise NotImplementedError, "id: #{id}"
    end

    def encode_primitive(type_def, value)
      primitive = type_def[:primitive]
      return ScaleRb2.encode_uint(primitive, value) if uint?(primitive)
      return ScaleRb2.encode_string(value) if string?(primitive)
      return ScaleRb2.encode_boolean(value) if boolean?(primitive)
    end

    def encode_compact(value)
      ScaleRb2.encode_compact(value)
    end

    def encode_array(id, array_type, value, registry)
      length = array_type[:len]
      inner_type_id = array_type[:type]
      raise LengthNotEqualErr, "id: #{id}, value: #{value.inspect}" if length != value.length

      _encode_types([inner_type_id] * length, value, registry)
    end

    def encode_sequence(sequence_type, value, registry)
      inner_type_id = sequence_type[:type]
      length_bytes = encode_compact(value.length)
      length_bytes + _encode_types([inner_type_id] * array.length, value, registry)
    end

    def encode_tuple(tuple_type, value, registry)
      _encode_types(tuple_type, value, registry)
    end

    # value:
    # {
    #   name: value,
    #   ...
    # }
    def encode_composite(composite_type, value, registry)
      fields = composite_type[:fields]
      type_id_list = fields.map { |f| f[:type] }
      _encode_types(type_id_list, value.values, registry)
    end

    # value:
    # {
    #   name: the_value
    # }
    # or
    # the_value
    def encode_variant(id, variant_type, value, registry)
      variants = variant_type[:variants]

      if value.instance_of?(Hash)
        name = value.keys.first
        the_value = value.values.first

        variant = variants.find { |v| v[:name] == name }
        index = variant[:index]
        fields = variant[:fields]
        raise ScaleRb2::InvalidValueError, "id: #{id}, index: #{index}, value: #{value}" if fields.empty?

        type_id_list = fields.map { |f| f[:type] }
        ScaleRb2.encode_uint('u8', index) + _encode_types(type_id_list, the_value, registry)
      elsif value.instance_of?(String)
        variant = variants.find { |v| v[:name] == value }
        index = variant[:index]
        fields = variant[:fields]
        raise ScaleRb2::InvalidValueError, "id: #{id}, index: #{index}, value: #{value}" unless fields.empty?

        ScaleRb2.encode_uint('u8', index)
      else
        raise ScaleRb2::InvalidValueError, "id: #{id}, value: #{value}"
      end
    end

    def _encode_types(type_id_list, value_list, registry)
      if type_id_list.empty?
        []
      else
        bytes = encode(type_id_list.first, value_list.first, registry)
        bytes + _encode_types(type_id_list[1..], value_list[1..], registry)
      end
    end
  end
end
