# frozen_string_literal: true

# rubocop:disable all
module ScaleRb
  module Encode
    extend TypeEnforcer
    include Types

    __ :encode, { id: Ti, value: Any, registry: Registry }, U8Array, level: 3
    def encode(id, value, registry)
      ScaleRb.logger.debug("Encoding #{id}, value: #{value}")
      type = registry[id]
      raise Codec::TypeNotFound, "id: #{id}" if type.nil?

      case type # type: PortableType
      when PrimitiveType then encode_primitive(type, value)
      when CompactType then encode_compact(value)
      when ArrayType then encode_array(type, value, registry)
      when SequenceType then encode_sequence(type, value, registry)
      when TupleType then encode_tuple(type, value, registry)
      when StructType then encode_struct(type, value, registry)
      when UnitType then []
      when VariantType then encode_variant(type, value, registry)
      else raise Codec::TypeNotImplemented, "encoding id: #{id}, type: #{type}"
      end
    end

    __ :encode_primitive, { type: PrimitiveType, value: Any }, U8Array
    def encode_primitive(type, value)
      primitive = type.primitive.to_s
      ScaleRb.logger.debug("Encoding primitive: #{primitive}, value: #{value}")

      return ScaleRb::CodecUtils.encode_uint(primitive, value) if primitive.start_with?('U')
      return ScaleRb::CodecUtils.encode_int(primitive, value) if primitive.start_with?('I')
      return ScaleRb::CodecUtils.encode_string(value) if primitive == 'Str'
      return ScaleRb::CodecUtils.encode_boolean(value) if primitive == 'Bool'

      raise Codec::TypeNotImplemented, "encoding primitive: #{primitive}"
    end

    __ :encode_compact, { value: Ti }, U8Array
    def encode_compact(value)
      ScaleRb.logger.debug("Encoding compact: #{value}")

      ScaleRb::CodecUtils.encode_compact(value)
    end

    __ :encode_array, { array_type: ArrayType, value: Array.of(Any), registry: Registry }, U8Array
    def encode_array(array_type, value, registry)
      ScaleRb.logger.debug("Encoding array: #{array_type}, value: #{value}")

      len = array_type.len
      inner_type_id = array_type.type

      _encode_types([inner_type_id] * len, value, registry)
    end

    __ :encode_sequence, { sequence_type: SequenceType, value: Array.of(Any), registry: Registry }, U8Array
    def encode_sequence(sequence_type, value, registry)
      ScaleRb.logger.debug("Encoding sequence: #{sequence_type}, value: #{value}")

      len = value.length
      inner_type_id = sequence_type.type

      encode_compact(len) + _encode_types([inner_type_id] * len, value, registry)
    end

    __ :encode_tuple, { tuple_type: TupleType, value: Array.of(Any) | Any, registry: Registry }, U8Array
    def encode_tuple(tuple_type, value, registry)
      ScaleRb.logger.debug("Encoding tuple: #{tuple_type}, value: #{value}")

      type_ids = tuple_type.tuple

      # For example: if the tuple type is (AccountId32), the value can be a AccountId32
      # TODO: Check if this is correct
      value = [value] if type_ids.length == 1

      _encode_types(type_ids, value, registry)
    end

    __ :encode_struct, { struct_type: StructType, value: Hash.map(Symbol, Any), registry: Registry }, U8Array
    def encode_struct(struct_type, value, registry)
      ScaleRb.logger.debug("Encoding struct: #{struct_type}, value: #{value}")

      fields = struct_type.fields

      type_ids = fields.map(&:type)
      _encode_types(type_ids, value.values, registry)
    end

    __ :encode_variant, { variant_type: VariantType, value: Nil | String | Integer | Symbol | HashMap[Symbol, Any], registry: Registry }, U8Array
    def encode_variant(variant_type, value, registry)
      ScaleRb.logger.debug("Encoding variant: #{variant_type}, value: #{value}")

      if variant_type.option?
        if value.nil?
          name = :None
        else
          name = :Some
        end
      else
        name = value.is_a?(::Symbol) ? value : value.keys.first
      end

      variant = variant_type.variants.find { |v| v.name == name }
      raise Codec::VariantItemNotFound, "type: #{variant_type}, name: #{value}" if variant.nil?

      case variant
      when SimpleVariant
        ScaleRb::CodecUtils.encode_uint('U8', variant.index)
      when TupleVariant
        # value example1: {:X2=>[{:Parachain=>12}, {:PalletInstance=>34}]}
        # value.values.first: [[{:Parachain=>12}, {:PalletInstance=>34}]]
        #
        # value example2: {:Parachain=>12}
        # value.values.first: 12
        ScaleRb::CodecUtils.encode_uint('U8', variant.index) + encode_tuple(variant.tuple, value.values.first, registry)
      when StructVariant
        # value example: {
        #   :Transact=>{
        #     :origin_type=>:SovereignAccount, 
        #     :require_weight_at_most=>5000000000,
        #     :call=>...
        #   }
        # }
        # value.values.first: {
        #   :origin_type=>:SovereignAccount,
        #   :require_weight_at_most=>5000000000,
        #   :call=>...
        # }
        ScaleRb::CodecUtils.encode_uint('U8', variant.index) + encode_struct(variant.struct, value.values.first, registry)
      end
    end

    private

    # @param type_ids [Array<Ti>] Array of type identifiers
    # @param values [Array<Any>] Array of values to encode
    # @param registry [Registry] Registry of types
    # @return [U8Array] Encoded bytes
    def _encode_types(type_ids, values, registry)
      raise Codec::LengthNotEqualErr, "type_ids: #{type_ids}, values: #{values.inspect}" if type_ids.length != values.length

      type_ids.each_with_index.reduce([]) do |memo, (type_id, i)|
        memo + encode(type_id, values[i], registry)
      end
    end

  end
end
