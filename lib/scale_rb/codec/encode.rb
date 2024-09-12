# frozen_string_literal: true

module ScaleRb
  module Codec
    class << self
      # % encode :: Ti -> Any -> Array<PortableType> -> U8Array
      def encode(ti, value, registry)
        ScaleRb.logger.debug("Encoding #{ti}, value: #{value}")
        type = registry[ti]
        raise TypeNotFound, "ti: #{ti}" if type.nil?

        case type # type: PortableType
        when ScaleRb::PrimitiveType then encode_primitive(type, value)
        when ScaleRb::CompactType then encode_compact(value)
        when ScaleRb::ArrayType then encode_array(type, value, registry)
        when ScaleRb::SequenceType then encode_sequence(type, value, registry)
        when ScaleRb::TupleType then encode_tuple(type, value, registry)
        when ScaleRb::StructType then encode_struct(type, value, registry)
        when ScaleRb::UnitType then []
        when ScaleRb::VariantType then encode_variant(type, value, registry)
        else raise TypeNotImplemented, "encoding ti: #{ti}, type: #{type}"
        end
      end

      # % encode_primitive :: PrimitiveType -> Any -> U8Array
      def encode_primitive(type, value)
        primitive = type.primitive
        ScaleRb.logger.debug("Encoding primitive: #{primitive}, value: #{value}")

        return ScaleRb.encode_uint(primitive, value) if primitive.start_with?('U')
        return ScaleRb.encode_int(primitive, value) if primitive.start_with?('I')
        return ScaleRb.encode_string(value) if primitive == 'Str'
        return ScaleRb.encode_boolean(value) if primitive == 'Bool'

        raise TypeNotImplemented, "encoding primitive: #{primitive}"
      end

      # % encode_compact :: Integer -> U8Array
      def encode_compact(value)
        ScaleRb.logger.debug("Encoding compact: #{value}")

        ScaleRb.encode_compact(value)
      end

      # % encode_array :: ArrayType -> Array<Any> -> Array<PortableType> -> U8Array
      def encode_array(array_type, value, registry)
        ScaleRb.logger.debug("Encoding array: #{array_type}, value: #{value}")

        len = array_type.len
        inner_type_id = array_type.type

        _encode_types([inner_type_id] * len, value, registry)
      end

      # % encode_sequence :: SequenceType -> Array<Any> -> Array<PortableType> -> U8Array
      def encode_sequence(sequence_type, value, registry)
        ScaleRb.logger.debug("Encoding sequence: #{sequence_type}, value: #{value}")

        len = value.length
        inner_type_id = sequence_type.type

        encode_compact(len) + _encode_types([inner_type_id] * len, value, registry)
      end

      # % encode_tuple :: TupleType -> Array<Any> -> Array<PortableType> -> U8Array
      def encode_tuple(tuple_type, value, registry)
        ScaleRb.logger.debug("Encoding tuple: #{tuple_type}, value: #{value}")

        _encode_types(tuple_type.tuple, value, registry)
      end

      # % encode_struct :: StructType -> Hash<Symbol, Any> -> Array<PortableType> -> U8Array
      def encode_struct(struct_type, value, registry)
        ScaleRb.logger.debug("Encoding struct: #{struct_type}, value: #{value}")

        fields = struct_type.fields

        type_ids = fields.map(&:type)
        _encode_types(type_ids, value.values, registry)
      end

      # % encode_variant :: VariantType -> Symbol | Hash<Symbol, Any> -> Array<PortableType> -> U8Array
      def encode_variant(variant_type, value, registry)
        ScaleRb.logger.debug("Encoding variant: #{variant_type}, value: #{value}")

        name = value.is_a?(Symbol) ? value : value.keys.first
        variant = variant_type.variants.find { |v| v.name == name }
        raise VariantItemNotFound, "type: #{variant_type}, name: #{value}" if variant.nil?

        case variant
        when ScaleRb::SimpleVariant
          ScaleRb.encode_uint('U8', variant.index)
        when ScaleRb::TupleVariant
          ScaleRb.encode_uint('U8', variant.index) + encode_tuple(variant.tuple, value.values.first, registry)
        when ScaleRb::StructVariant
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
