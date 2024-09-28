# frozen_string_literal: true

require 'scale_rb'

class TestRegistry
  def initialize(types = [])
    @types = types
  end

  def add_type(type)
    @types << type
  end

  def get_type(type_id)
    @types[type_id]
  end
end

RSpec.describe ScaleRb::Types do
  it 'can create a primitive type' do
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    expect(p0).to be_a(ScaleRb::Types::PrimitiveType)
    expect(p0.primitive).to eq('U8')
    expect(p0.to_s).to eq('U8')
  end

  it 'can create a compact type' do
    p1 = ScaleRb::Types::CompactType.new
    expect(p1).to be_a(ScaleRb::Types::CompactType)
    expect(p1.to_s).to eq('Compact')
  end

  it 'can create a compact type with a inner type' do
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    registry = TestRegistry.new([p0])

    p2 = ScaleRb::Types::CompactType.new(type: 0, registry:)
    expect(p2).to be_a(ScaleRb::Types::CompactType)
    expect(p2.to_s).to eq('Compact<U8>')
  end

  it 'can create a sequence type' do
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    registry = TestRegistry.new([p0])

    p3 = ScaleRb::Types::SequenceType.new(type: 0, registry:)
    expect(p3).to be_a(ScaleRb::Types::SequenceType)
    expect(p3.to_s).to eq('[U8]')
  end

  it 'can create a array type' do
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    registry = TestRegistry.new([p0])

    p4 = ScaleRb::Types::ArrayType.new(type: 0, len: 3, registry:)
    expect(p4).to be_a(ScaleRb::Types::ArrayType)
    expect(p4.to_s).to eq('[U8; 3]')
  end

  it 'can create a tuple type' do
    registry = TestRegistry.new
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    registry.add_type(p0)

    p1 = ScaleRb::Types::CompactType.new
    registry.add_type(p1)

    p2 = ScaleRb::Types::CompactType.new(type: 0, registry:)
    registry.add_type(p2)

    p5 = ScaleRb::Types::TupleType.new(tuple: [0, 1, 2], registry:)
    expect(p5).to be_a(ScaleRb::Types::TupleType)
    expect(p5.to_s).to eq('(U8, Compact, Compact<U8>)')
  end

  it 'can create a struct type' do
    registry = TestRegistry.new
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    registry.add_type(p0)

    p1 = ScaleRb::Types::CompactType.new
    registry.add_type(p1)

    p6 = ScaleRb::Types::StructType.new(
      fields: [
        ScaleRb::Types::Field.new(name: 'name', type: 0),
        ScaleRb::Types::Field.new(name: 'age', type: 1)
      ],
      registry:
    )
    expect(p6.to_s).to eq('{ name: U8, age: Compact }')
  end

  it 'can create a unit type' do
    p7 = ScaleRb::Types::UnitType.new
    expect(p7.to_s).to eq('()')
  end

  it 'can create a variant type' do
    registry = TestRegistry.new
    p0 = ScaleRb::Types::PrimitiveType.new(primitive: 'U8')
    registry.add_type(p0)

    p1 = ScaleRb::Types::CompactType.new
    registry.add_type(p1)

    p2 = ScaleRb::Types::CompactType.new(type: 0, registry:)
    registry.add_type(p2)

    p5 = ScaleRb::Types::TupleType.new(tuple: [0, 1, 2], registry:)
    registry.add_type(p5)

    p6 = ScaleRb::Types::StructType.new(
      fields: [
        ScaleRb::Types::Field.new(name: 'name', type: 0),
        ScaleRb::Types::Field.new(name: 'age', type: 1)
      ],
      registry:
    )
    registry.add_type(p6)

    p8 = ScaleRb::Types::VariantType.new(
      variants: [
        ScaleRb::Types::TupleVariant.new(name: :Bar, index: 1, tuple: p5),
        ScaleRb::Types::SimpleVariant.new(name: :Foo, index: 0),
        ScaleRb::Types::StructVariant.new(name: :Baz, index: 2, struct: p6)
      ],
      registry:
    )
    expect(p8.to_s).to eq('Foo | Bar(U8, Compact, Compact<U8>) | Baz { name: U8, age: Compact }')
  end
end
