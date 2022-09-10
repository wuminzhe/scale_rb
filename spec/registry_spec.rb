# frozen_string_literal: true

require 'scale_rb_2'

RSpec.describe ScaleRb2 do
  it 'get mapped type' do
    registry = {
    }
    type = ScaleRb2.get_final_type_from_registry(registry, 'CustomType')
    expect(type).to be(nil)

    registry = {
      'CustomType' => 'Vec<u8>'
    }
    type = ScaleRb2.get_final_type_from_registry(registry, 'CustomType')
    expect(type).to eql('Vec<u8>')

    registry = {
      'CustomType' => 'Type1',
      'Type1' => 'Vec<u8>'
    }
    type = ScaleRb2.get_final_type_from_registry(registry, 'CustomType')
    expect(type).to eql('Vec<u8>')

    registry = {
      'CustomType' => 'Type1',
      'Type1' => 'Type2',
      'Type2' => 'Vec<u8>'
    }
    type = ScaleRb2.get_final_type_from_registry(registry, 'CustomType')
    expect(type).to eql('Vec<u8>')
  end
end
