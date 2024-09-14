# frozen_string_literal: true

module ScaleRb
  class << self
    # % build_types_from_portable_registry :: Array<Hash> -> Array<TypeDef>
    def build_types_from_portable_registry(data)
      data.map.with_index do |type, i|
        id = type._get(:id)
        raise "Invalid type id: #{id}" if id.nil? || id != i

        def_ = type._get(:type, :def)
        raise "No 'def' found: #{type}" if def_.nil?

        type_name = def_.keys.first.to_sym
        type_def = def_._get(type_name)
        _build_type(type_name, type_def)
      end
    end

    private

    def _build_type(type_name, type_def)
      case type_name
      when :primitive
        ScaleRb::PrimitiveType.new(type_def)
      when :compact
        ScaleRb::CompactType.new(type_def._get(:type))
      when :sequence
        ScaleRb::SequenceType.new(type_def._get(:type))
      when :bitSequence
        ScaleRb::BitSequenceType.new(
          type_def._get(:bitStoreType),
          type_def._get(:bitOrderType)
        )
      when :array
        ScaleRb::ArrayType.new(
          type_def._get(:len),
          type_def._get(:type)
        )
      when :tuple
        ScaleRb::TupleType.new(type_def)
      when :composite
        fields = type_def._get(:fields)
        first_field = fields.first

        return ScaleRb::UnitType.new unless first_field # no fields
        return ScaleRb::TupleType.new(fields.map { |f| f._get(:type) }) unless first_field._get(:name)

        ScaleRb::StructType.new(
          fields.map do |f|
            Field.new(f._get(:name), f._get(:type))
          end
        )
      when :variant
        variants = type_def._get(:variants)
        return ScaleRb::VariantType.new([]) if variants.empty?

        variant_list = variants.map do |v|
          fields = v._get(:fields)
          if fields.empty?
            ScaleRb::SimpleVariant.new(v._get(:name).to_sym, v._get(:index))
          elsif fields.first._get(:name).nil?
            ScaleRb::TupleVariant.new(
              v._get(:name).to_sym,
              v._get(:index),
              fields.map { |f| f._get(:type) }
            )
          else
            ScaleRb::StructVariant.new(
              v._get(:name).to_sym,
              v._get(:index),
              fields.map { |f| Field.new(f._get(:name), f._get(:type)) }
            )
          end
        end
        ScaleRb::VariantType.new(variant_list)
      end
    end
  end
end
