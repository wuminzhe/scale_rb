# frozen_string_literal: true

# rubocop:disable all
module ScaleRb
  class PortableRegistry
    extend TypeEnforcer
    include Types

    attr_reader :data, :types

    sig :initialize, { data: Array.of(Hash) }
    def initialize(data)
      @data = data
      @types = ::Array.new(@data.size)
      build_types
    end

    sig :[], { index: Ti }, PortableType
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

    sig :_build_type, { id: Ti, type_name: Symbol, type_def: Hash | String | Array, path: Strict::Array.of(Strict::String) }, PortableType
    def _build_type(id, type_name, type_def, path)
      case type_name
      when :primitive
        # type_def: 'I32'
        PrimitiveType.new(primitive: type_def, path: path)
      when :compact
        # type_def: { type: 1 }
        CompactType.new(type: type_def._get(:type), registry: self, path: path)
      when :sequence
        # type_def: { type: 9 }
        SequenceType.new(type: type_def._get(:type), registry: self, path: path)
      when :bitSequence
        raise NotImplementedError, 'bitSequence not implemented'
      when :array
        # type_def: { len: 3, type: 1 }
        ArrayType.new(
          len: type_def._get(:len),
          type: type_def._get(:type),
          registry: self,
          path: path
        )
      when :tuple
        # type_def: [1, 2, 3]
        TupleType.new(tuple: type_def, registry: self, path: path)
      when :composite
        fields = type_def._get(:fields)
        first_field = fields.first

        # type_def: {"fields"=>[]}
        return UnitType.new(path: path) if first_field.nil?

        # type_def: {"fields"=>[{"name"=>nil, "type"=>1}, {"name"=>nil, "type"=>2}]}
        return TupleType.new(tuple: fields.map { |f| f._get(:type) }, registry: self, path: path) unless first_field._get(:name)

        # type_def: { fields: [{ name: 'name', type: 1 }, { name: 'age', type: 2 }] }
        StructType.new(
          fields: fields.map do |field|
            Field.new(name: field._get(:name), type: field._get(:type))
          end,
          registry: self,
          path: path
        )
      when :variant
        variants = type_def._get(:variants)

        # type_def: {"variants"=>[]}
        return VariantType.new(variants: [], path: path) if variants.empty?

        variant_list = variants.map do |v|
          fields = v._get(:fields)
          if fields.empty?
            # variant: {"name"=>"Vouching", "fields"=>[], "index"=>0, "docs"=>[]}
            SimpleVariant.new(name: v._get(:name).to_sym, index: v._get(:index))
          elsif fields.first._get(:name).nil?
            # variant: {"name"=>"Seal", "fields"=>[{"name"=>nil, "type"=>15, "typeName"=>"ConsensusEngineId", "docs"=>[]}, {"name"=>nil, "type"=>11, "typeName"=>"Vec<u8>", "docs"=>[]}], "index"=>5, "docs"=>[]},
            TupleVariant.new(
              name: v._get(:name).to_sym,
              index: v._get(:index),
              tuple: TupleType.new(
                tuple: fields.map { |field| field._get(:type) },
                registry: self
              )
            )
          else
            # variant: {"name"=>"ExtrinsicSuccess", "fields"=>[{"name"=>"dispatch_info", "type"=>20, "typeName"=>"DispatchInfo", "docs"=>[]}], "index"=>0, "docs"=>["An extrinsic completed successfully."]},
            StructVariant.new(
              name: v._get(:name).to_sym,
              index: v._get(:index),
              struct: StructType.new(
                fields: fields.map { |field| Field.new(name: field._get(:name), type: field._get(:type)) },
                registry: self
              )
            )
          end
        end
        VariantType.new(variants: variant_list, path: path)
      end
    end
  end
end
