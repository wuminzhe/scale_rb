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

  it 'decode complex array' do
    registry = {
      'CustomType1' => 'Type1',
      'Type1' => 'u8',
      'CustomType2' => 'u16'
    }
    type = '[([CustomType1; 3], CustomType2); 2]'
    bytes = [
      0x12, 0x34, 0x56, 0x2e, 0xfb,
      0x12, 0x34, 0x56, 0x2e, 0xfb,
      0x78
    ]
    arr, remaining_bytes = ScaleRb2.do_decode(type, bytes, registry)
    expect(arr).to eql([
                         [[0x12, 0x34, 0x56], 64_302],
                         [[0x12, 0x34, 0x56], 64_302]
                       ])
    expect(remaining_bytes).to eql([0x78])
  end

  it 'encode complex array' do
    registry = {
      'CustomType1' => 'Type1',
      'Type1' => 'Compact',
      'CustomType2' => 'u16'
    }
    type = '[([CustomType1; 3], CustomType2); 2]'
    value = [
      [[1, 1_073_741_824, 69], 64_302],
      [[63, 42, 1_073_741_823], 64_302]
    ]
    bytes = ScaleRb2.do_encode(type, value, registry)
    expect(bytes).to eql([
                           0x04, 0x03, 0x00, 0x00, 0x00, 0x40, 0x15, 0x01, 0x2e, 0xfb,
                           0xfc, 0xa8, 0xfe, 0xff, 0xff, 0xff, 0x2e, 0xfb
                         ])
  end
end
