# frozen_string_literal: true

require_relative '../type_enforcer'

# rubocop:disable all
module ScaleRb
  class PortableRegistry
    extend TypeEnforcer

    attr_reader :data, :types

    sig :initialize, { data: Types::Array.of(Types::Hash) }
    def initialize(data)
      @data = data
      @types = Array.new(@data.size)
      build_types
    end

    sig :[], { index: Types::Ti }, Types::PortableType
    def [](index)
      @types[index]
    end

    private

    sig :build_types, {}
    def build_types
      @data.each.with_index do |type, i|
        id = type._get(:id)
        raise "Invalid type id: #{id}" if id.nil? || id != i

        def_ = type._get(:type, :def)
        raise "No 'def' found: #{type}" if def_.nil?

        path = type._get(:type, :path)

        type_name = def_.keys.first.to_sym
        type_def = def_._get(type_name)
        @types[id] = _build_type(id, type_name, type_def, path)
      end
    end

    sig :_build_type, { id: Types::Ti, type_name: Types::Symbol, type_def: Types::Hash | Types::String | Types::Array, path: Types::Strict::Array.of(Types::Strict::String) }, Types::PortableType
    def _build_type(id, type_name, type_def, path)
      case type_name
      when :primitive
        # type_def: 'I32'
        Types::PrimitiveType.new(primitive: type_def, path: path)
      when :compact
        # type_def: { type: 1 }
        Types::CompactType.new(type: type_def._get(:type), registry: self, path: path)
      when :sequence
        # type_def: { type: 9 }
        Types::SequenceType.new(type: type_def._get(:type), registry: self, path: path)
      when :bitSequence
        raise NotImplementedError, 'bitSequence not implemented'
      when :array
        # type_def: { len: 3, type: 1 }
        Types::ArrayType.new(
          len: type_def._get(:len),
          type: type_def._get(:type),
          registry: self,
          path: path
        )
      when :tuple
        # type_def: [1, 2, 3]
        Types::TupleType.new(tuple: type_def, registry: self, path: path)
      when :composite
        fields = type_def._get(:fields)
        first_field = fields.first

        # type_def: {"fields"=>[]}
        return Types::UnitType.new(path: path) if first_field.nil?

        # type_def: {"fields"=>[{"name"=>nil, "type"=>1}, {"name"=>nil, "type"=>2}]}
        return Types::TupleType.new(tuple: fields.map { |f| f._get(:type) }, registry: self, path: path) unless first_field._get(:name)

        # type_def: { fields: [{ name: 'name', type: 1 }, { name: 'age', type: 2 }] }
        Types::StructType.new(
          fields: fields.map do |field|
            Types::Field.new(name: field._get(:name), type: field._get(:type))
          end,
          registry: self,
          path: path
        )
      when :variant
        variants = type_def._get(:variants)

        # type_def: {"variants"=>[]}
        return Types::VariantType.new(variants: [], path: path) if variants.empty?

        variant_list = variants.map do |v|
          fields = v._get(:fields)
          if fields.empty?
            # variant: {"name"=>"Vouching", "fields"=>[], "index"=>0, "docs"=>[]}
            Types::SimpleVariant.new(name: v._get(:name).to_sym, index: v._get(:index))
          elsif fields.first._get(:name).nil?
            # variant: {"name"=>"Seal", "fields"=>[{"name"=>nil, "type"=>15, "typeName"=>"ConsensusEngineId", "docs"=>[]}, {"name"=>nil, "type"=>11, "typeName"=>"Vec<u8>", "docs"=>[]}], "index"=>5, "docs"=>[]},
            Types::TupleVariant.new(
              name: v._get(:name).to_sym,
              index: v._get(:index),
              tuple: Types::TupleType.new(
                tuple: fields.map { |field| field._get(:type) },
                registry: self
              )
            )
          else
            # variant: {"name"=>"ExtrinsicSuccess", "fields"=>[{"name"=>"dispatch_info", "type"=>20, "typeName"=>"DispatchInfo", "docs"=>[]}], "index"=>0, "docs"=>["An extrinsic completed successfully."]},
            Types::StructVariant.new(
              name: v._get(:name).to_sym,
              index: v._get(:index),
              struct: Types::StructType.new(
                fields: fields.map { |field| Types::Field.new(name: field._get(:name), type: field._get(:type)) },
                registry: self
              )
            )
          end
        end
        Types::VariantType.new(variants: variant_list, path: path)
      end
    end
  end
end
