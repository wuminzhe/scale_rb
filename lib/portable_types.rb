# frozen_string_literal: true

module PortableTypes
  class << self
    def decode(id, bytes, registry)
      type = registry[id]
      raise "TypeNotFound, id: #{id}" if type.nil?

      _path = type['path']
      _params = type['params']
      type_def = type['def']

      return decode_primitive(id, type_def, bytes) if type_def.key?('primitive')
      return decode_compact(bytes) if type_def.key?('compact')
      return decode_array(type_def['array'], bytes, registry) if type_def.key?('array')
      return decode_sequence(id, type_def['sequence'], bytes, registry) if type_def.key?('sequence')
      return decode_tuple(id, type_def['tuple'], bytes, registry) if type_def.key?('tuple')
      return decode_composite(type_def['composite'], bytes, registry) if type_def.key?('composite')
      return decode_variant(id, type_def['variant'], bytes, registry) if type_def.key?('variant')

      raise NotImplementedError
    end

    # U, Str, Bool
    # I, Bytes ?
    def decode_primitive(_id, type_def, bytes)
      primitive = type_def['primitive']

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
      len = array_type['len']
      inner_type_id = array_type['type']
      _decode_types([inner_type_id] * len, bytes, registry)
    end

    def decode_sequence(_id, sequence_type, bytes, registry)
      len, remaining_bytes = decode_compact(bytes)
      inner_type_id = sequence_type['type']
      _decode_types([inner_type_id] * len, remaining_bytes, registry)
    end

    def decode_tuple(_id, tuple_type, bytes, registry)
      _decode_types(tuple_type, bytes, registry)
    end

    # [
    #   [name, value],
    #   ...
    # ]
    def decode_composite(composite_type, bytes, registry)
      fields = composite_type['fields']

      type_name_list = fields.map { |f| f['name'] }
      type_id_list = fields.map { |f| f['type'] }

      type_value_list, remaining_bytes = _decode_types(type_id_list, bytes, registry)
      [
        type_name_list.all?(&:nil?) ? type_value_list : [type_name_list, type_value_list].transpose,
        remaining_bytes
      ]
    end

    def decode_variant(_id, variant_type, bytes, registry)
      variants = variant_type['variants']

      index = bytes[0]
      puts index
      puts (variants.length - 1)
      raise ScaleRb2::IndexOutOfRangeError, "type: #{variant_type}, bytes: #{bytes}" if index > (variants.length - 1)
      puts '------------------'

      item_variant = variants.find { |v| v['index'] == index }
      item_name = item_variant['name']
      item, remaining_bytes = decode_composite(item_variant, bytes[1..], registry)

      [
        item.empty? ? item_name : [item_name, item],
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
  end
end
