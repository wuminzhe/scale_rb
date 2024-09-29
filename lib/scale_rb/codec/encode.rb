# frozen_string_literal: true

# rubocop:disable all
module ScaleRb
  module Codec
    class << self
      extend TypeEnforcer
      include Types

      sig :encode, [Ti, Any, Registry], Hex
      def encode(ti, value, registry)
        ScaleRb.logger.debug("Encoding #{ti}, value: #{value}")
        type = registry[ti]
        raise TypeNotFound, "ti: #{ti}" if type.nil?

        case type # type: PortableType
        when PrimitiveType then encode_primitive(type, value)
        when CompactType then encode_compact(value)
        when ArrayType then encode_array(type, value, registry)
        when SequenceType then encode_sequence(type, value, registry)
        when TupleType then encode_tuple(type, value, registry)
        when StructType then encode_struct(type, value, registry)
        when UnitType then []
        when VariantType then encode_variant(type, value, registry)
        else raise TypeNotImplemented, "encoding ti: #{ti}, type: #{type}"
        end
      end

      sig :encode_primitive, [PrimitiveType, Any], Hex
      def encode_primitive(type, value)
        primitive = type.primitive
        ScaleRb.logger.debug("Encoding primitive: #{primitive}, value: #{value}")

        return ScaleRb.encode_uint(primitive, value) if primitive.start_with?('U')
        return ScaleRb.encode_int(primitive, value) if primitive.start_with?('I')
        return ScaleRb.encode_string(value) if primitive == 'Str'
        return ScaleRb.encode_boolean(value) if primitive == 'Bool'

        raise TypeNotImplemented, "encoding primitive: #{primitive}"
      end

      sig :encode_compact, [Ti], Hex
      def encode_compact(value)
        ScaleRb.logger.debug("Encoding compact: #{value}")

        ScaleRb.encode_compact(value)
      end

      sig :encode_array, [ArrayType, Array.of(Any), Registry], Hex
      def encode_array(array_type, value, registry)
        ScaleRb.logger.debug("Encoding array: #{array_type}, value: #{value}")

        len = array_type.len
        inner_type_id = array_type.type

        _encode_types([inner_type_id] * len, value, registry)
      end

      sig :encode_sequence, [SequenceType, Array.of(Any), Registry], Hex
      def encode_sequence(sequence_type, value, registry)
        ScaleRb.logger.debug("Encoding sequence: #{sequence_type}, value: #{value}")

        len = value.length
        inner_type_id = sequence_type.type

        encode_compact(len) + _encode_types([inner_type_id] * len, value, registry)
      end

      sig :encode_tuple, [TupleType, Array.of(Any), Registry], Hex
      def encode_tuple(tuple_type, value, registry)
        ScaleRb.logger.debug("Encoding tuple: #{tuple_type}, value: #{value}")

        type_ids = tuple_type.tuple

        # For example: if the tuple type is (AccountId32), the value can be a AccountId32
        # TODO: Check if this is correct
        value = [value] if type_ids.length == 1

        _encode_types(type_ids, value, registry)
      end

      sig :encode_struct, [StructType, Hash.map(Symbol, Any), Registry], Hex
      def encode_struct(struct_type, value, registry)
        ScaleRb.logger.debug("Encoding struct: #{struct_type}, value: #{value}")

        fields = struct_type.fields

        type_ids = fields.map(&:type)
        _encode_types(type_ids, value.values, registry)
      end

      sig :encode_variant, [VariantType, Symbol | Hash.map(Symbol, Any), Registry], Hex
      def encode_variant(variant_type, value, registry)
        ScaleRb.logger.debug("Encoding variant: #{variant_type}, value: #{value}")

        name = value.is_a?(::Symbol) ? value : value.keys.first
        variant = variant_type.variants.find { |v| v.name == name }
        raise VariantItemNotFound, "type: #{variant_type}, name: #{value}" if variant.nil?

        case variant
        when SimpleVariant
          ScaleRb.encode_uint('U8', variant.index)
        when TupleVariant
          ScaleRb.encode_uint('U8', variant.index) + encode_tuple(variant.tuple, value.values.first, registry)
        when StructVariant
          ScaleRb.encode_uint('U8', variant.index) + encode_struct(variant.struct, value.values.first, registry)
        end
      end

      private

      # _encode_types :: Array<Ti> -> Array<Any> -> Array<PortableType> -> U8Array
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
