# frozen_string_literal: true

require 'scale_rb'
require 'json'

module ScaleRb
  RSpec.describe "Type" do
    before(:all) do
      hex = File.read("./spec/assets/substrate-metadata-v14-hex").strip
      metadata = ScaleRb::Metadata.decode_metadata(hex)
      @types = ScaleRb::Metadata.build_registry(metadata)

      # data = JSON.parse(File.open(File.join(__dir__, 'assets', 'substrate-types.json')).read)
      # @types = ScaleRb.build_types(data)
    end

    it 'types are correct' do
      @types.each_with_index do |t, i|
        case t.kind
        when :Primitive
          primitives = ['I8', 'U8', 'I16', 'U16', 'I32', 'U32', 'I64', 'U64', 'I128', 'U128', 'I256', 'U256', 'Bool', 'Str', 'Char',]
          expect(primitives).to include(t.primitive)
        when :Compact
          # p @types[t.type]
          expect(t.type).to be_a(Integer)
        when :Sequence
          # p @types[t.type]
          expect(t.type).to be_a(Integer)
        when :BitSequence
          p t
          expect(t.bit_store_type).to be_a(Integer)
          expect(t.bit_order_type).to be_a(Integer)
        when :Array
          expect(t.len).to be_a(Integer)
          expect(t.type).to be_a(Integer)
        when :Tuple
          expect(t.tuple).to be_a(Array)
        when :Composite
          expect(t.fields).to be_a(Array)
          t.fields.each do |f|
            expect(f.name).to be_a(String)
            expect(f.type).to be_a(Integer)
          end
        when :Unit
          expect(t).to be_a(ScaleRb::UnitType)
        when :Variant

          case t.variant_kind
          when :Simple
            expect(t.variants).to be_a(Array)
            t.variants.each do |v|
              expect(v).to be_a(ScaleRb::SimpleVariant)
            end
          when :Tuple
            expect(t.variants).to be_a(Array)
            t.variants.each do |v|
              expect(v).to be_a(ScaleRb::TupleVariant)
            end
          when :Struct
            expect(t.variants).to be_a(Array)
            t.variants.each do |v|
              expect(v).to be_a(ScaleRb::StructVariant)
            end
          when :Void
            expect(t.variants).to be_a(NilClass)
          end

        end

      end
    end

  end
end
