# frozen_string_literal: true

require 'scale_rb'

RSpec.describe ScaleRb do
  it 'can decode fixed int' do
    value, remaining_bytes = ScaleRb.decode('i16', [0x2e, 0xfb])
    expect(value).to eql(-1234)
    expect(remaining_bytes).to eql([])
  end

  it 'can decode fixed uint' do
    value, remaining_bytes = ScaleRb.decode('u8', [0x45])
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb.decode('u8', [0x45, 0x12])
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([0x12])

    value, remaining_bytes = ScaleRb.decode('u16', [0x45, 0x00])
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([])

    expect { ScaleRb.decode('u16', [0x2e]) }.to raise_error(ScaleRb::NotEnoughBytesError)

    value, remaining_bytes = ScaleRb.decode('u16', [0x2e, 0xfb])
    expect(value).to eql(64_302)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb.decode('u16', [0x2e, 0xfb, 0xff])
    expect(value).to eql(64_302)
    expect(remaining_bytes).to eql([0xff])

    value, remaining_bytes = ScaleRb.decode('u32', [0xff, 0xff, 0xff, 0x00])
    expect(value).to eql(16_777_215)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb.decode('u64', [0x00, 0xe4, 0x0b, 0x54, 0x03, 0x00, 0x00, 0x00])
    expect(value).to eql(14_294_967_296)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb.decode('u128', '0x0bfeffffffffffff0000000000000000'.to_bytes)
    expect(value).to eql(18_446_744_073_709_551_115)
    expect(remaining_bytes).to eql([])
  end

  it 'can encode fixed uint' do
    bytes = ScaleRb.encode('u8', 69)
    expect(bytes).to eql([0x45])

    bytes = ScaleRb.encode('u16', 69)
    expect(bytes).to eql([0x45, 0x00])

    bytes = ScaleRb.encode('u16', 64_302)
    expect(bytes).to eql([0x2e, 0xfb])

    bytes = ScaleRb.encode('u32', 16_777_215)
    expect(bytes).to eql([0xff, 0xff, 0xff, 0x00])

    bytes = ScaleRb.encode('u64', 14_294_967_296)
    expect(bytes).to eql('0x00e40b5403000000'.to_bytes)

    bytes = ScaleRb.encode('u128', 18_446_744_073_709_551_115)
    expect(bytes).to eql('0x0bfeffffffffffff0000000000000000'.to_bytes)
  end

  it 'can decode fixed array' do
    arr, remaining_bytes = ScaleRb.decode('[u8; 3]', [0x12, 0x34, 0x56, 0x78])
    expect(arr).to eql([0x12, 0x34, 0x56])
    expect(remaining_bytes).to eql([0x78])

    arr, remaining_bytes = ScaleRb.decode('[u16; 2]', [0x2e, 0xfb, 0x2e, 0xfb])
    expect(arr).to eql([64_302, 64_302])
    expect(remaining_bytes).to eql([])

    arr, remaining_bytes = ScaleRb.decode('[[u8; 3]; 2]', [0x12, 0x34, 0x56, 0x12, 0x34, 0x56])
    expect(arr).to eql([[0x12, 0x34, 0x56], [0x12, 0x34, 0x56]])
    expect(remaining_bytes).to eql([])

    arr, remaining_bytes = ScaleRb.decode('[[u16; 2]; 2]', [0x2e, 0xfb, 0x2e, 0xfb, 0x2e, 0xfb, 0x2e, 0xfb])
    expect(arr).to eql([[64_302, 64_302], [64_302, 64_302]])
    expect(remaining_bytes).to eql([])
  end

  it 'can encode fixed array' do
    bytes = ScaleRb.encode('[u8; 3]', [0x12, 0x34, 0x56])
    expect(bytes).to eql([0x12, 0x34, 0x56])
  end

  it 'can decode compact' do
    value, = ScaleRb.decode('Compact', [254, 255, 3, 0])
    expect(value).to eql(0xffff)
  end

  it 'can decode single-byte compact uint' do
    value, = ScaleRb.decode('Compact', [0x00])
    expect(value).to eql(0)

    value, = ScaleRb.decode('Compact', [0x04])
    expect(value).to eql(1)

    value, = ScaleRb.decode('Compact', [0xa8])
    expect(value).to eql(42)

    value, = ScaleRb.decode('Compact', [0xfc])
    expect(value).to eql(63)
  end

  it 'can decode two-byte compact uint' do
    value, = ScaleRb.decode('Compact', '0x1501'.to_bytes)
    expect(value).to eql(69)
  end

  it 'can decode four-byte compact uint' do
    value, = ScaleRb.decode('Compact', '0xfeffffff'.to_bytes)
    expect(value).to eql(1_073_741_823)
  end

  it 'can decode big-integer compact uint' do
    value, = ScaleRb.decode('Compact', '0x0300000040'.to_bytes)
    expect(value).to eql(1_073_741_824)
  end

  it 'can decode struct' do
    struct = {
      item3: 'Compact',
      item1: '[u16; 2]',
      item2: 'Compact'
    }
    bytes = [0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01]
    value, = ScaleRb.decode(struct, bytes)
    expect(value).to eql({
                           item3: 63,
                           item1: [64_302, 64_302],
                           item2: 69
                         })
  end

  it 'can encode single-byte compact' do
    bytes = ScaleRb.encode('Compact', 0)
    expect(bytes).to eql([0x00])

    bytes = ScaleRb.encode('Compact', 1)
    expect(bytes).to eql([0x04])

    bytes = ScaleRb.encode('Compact', 42)
    expect(bytes).to eql([0xa8])

    bytes = ScaleRb.encode('Compact', 63)
    expect(bytes).to eql([0xfc])
  end

  it 'can encode two-byte compact' do
    bytes = ScaleRb.encode('Compact', 69)
    expect(bytes).to eql([0x15, 0x01])
  end

  it 'can encode four-byte compact' do
    bytes = ScaleRb.encode('Compact', 1_073_741_823)
    expect(bytes).to eql('0xfeffffff'.to_bytes)
  end

  it 'can encode big-integer compact' do
    bytes = ScaleRb.encode('Compact', 1_073_741_824)
    expect(bytes).to eql('0x0300000040'.to_bytes)
  end

  it 'can encode struct' do
    struct = {
      item3: 'Compact',
      item1: '[u16; 2]',
      item2: 'Compact'
    }
    bytes = ScaleRb.encode(struct, {
                                 item3: 63,
                                 item1: [64_302, 64_302],
                                 item2: 69
                               })
    expect(bytes).to eql([0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01])
  end

  it 'can decode enum' do
    enum = {
      _enum: {
        Int: 'u16',
        Compact: 'Compact'
      }
    }

    bytes = [0x00, 0x2e, 0xfb]
    value, = ScaleRb.decode(enum, bytes)
    expect(value).to eql({
                           Int: 64_302
                         })

    bytes = [0x01, 0x15, 0x01]
    value, = ScaleRb.decode(enum, bytes)
    expect(value).to eql({
                           Compact: 69
                         })

    expect { ScaleRb.decode(enum, [0x02, 0x15, 0x01]) }.to raise_error(ScaleRb::IndexOutOfRangeError)
  end

  it 'can encode enum' do
    enum = {
      _enum: {
        Int: 'u16',
        Compact: 'Compact'
      }
    }
    bytes = ScaleRb.encode(enum, { Int: 64_302 })
    expect(bytes).to eql([0x00, 0x2e, 0xfb])
  end

  it 'can decode vec' do
    arr, remaining_bytes = ScaleRb.decode('vec<u8>', '0x0c003afe'.to_bytes)
    expect(arr).to eql([0, 58, 254])
    expect(remaining_bytes).to eql([])
  end

  it 'can encode vec' do
    bytes = ScaleRb.encode('Vec<u8>', [0, 58, 254])
    expect(bytes).to eql('0x0c003afe'.to_bytes)
  end

  it 'can decode tuple' do
    value, = ScaleRb.decode('(Compact, [u16; 2], Compact)', [0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01])
    expect(value).to eql([63, [64_302, 64_302], 69])
  end

  it 'can encode tuple' do
    bytes = ScaleRb.encode('(Compact, [u16; 2], Compact)', [63, [64_302, 64_302], 69])
    expect(bytes).to eql([0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01])
  end

  it 'can decode string' do
    value, = ScaleRb.decode_string([20, 104, 101, 108, 108, 111])
    expect(value).to eql('hello')

    value, = ScaleRb.decode_string([24, 228, 189, 160, 229, 165, 189])
    expect(value).to eql('你好')
  end

  it 'can encode string' do
    bytes = ScaleRb.encode_string('hello')
    expect(bytes).to eql([20, 104, 101, 108, 108, 111])

    bytes = ScaleRb.encode_string('你好')
    expect(bytes).to eql([24, 228, 189, 160, 229, 165, 189])
  end

  it 'can decode boolean' do
    value, = ScaleRb.decode('Boolean', [0x00])
    expect(value).to eql(false)

    value, = ScaleRb.decode('Boolean', [0x01])
    expect(value).to eql(true)

    expect { ScaleRb.decode('Boolean', [0x02]) }.to raise_error(ScaleRb::InvalidBytesError)
  end

  it 'can encode boolean' do
    bytes = ScaleRb.encode('Boolean', false)
    expect(bytes).to eql([0x00])

    bytes = ScaleRb.encode('Boolean', true)
    expect(bytes).to eql([0x01])

    expect { ScaleRb.encode('Boolean', nil) }.to raise_error(ScaleRb::InvalidValueError)
  end

  it 'can decode bytes' do
    value, = ScaleRb.decode('Bytes', '0x14436166c3a9'.to_bytes)
    expect(value).to eql('0x436166c3a9')
  end

  it 'can encode bytes' do
    bytes = ScaleRb.encode('Bytes', '0x436166c3a9'.to_bytes)
    expect(bytes).to eql('0x14436166c3a9'.to_bytes)
  end

  it 'can decode option' do
    value, = ScaleRb.decode('Option<Compact>', '0x00'.to_bytes)
    expect(value).to eql(nil)

    value, = ScaleRb.decode('Option<Compact>', '0x011501'.to_bytes)
    expect(value).to eql(69)

    expect { ScaleRb.decode('Option<Compact>', '0x02') }.to raise_error(ScaleRb::InvalidBytesError)
  end

  it 'can encode option' do
    bytes = ScaleRb.encode('Option<Compact>', nil)
    expect(bytes).to eql([0x00])

    bytes = ScaleRb.encode('Option<Compact>', 69)
    expect(bytes).to eql([0x01, 0x15, 0x01])
  end

  it 'can encode uint' do
    # 2**64 - 1
    bytes = ScaleRb.encode('u256', 18446744073709551615)
    expect(bytes.to_hex).to eql("0xffffffffffffffff000000000000000000000000000000000000000000000000")

    # 2**64 - 1
    bytes = ScaleRb.encode('u64', 18446744073709551615)
    expect(bytes.to_hex).to eql('0xffffffffffffffff')

    # 2**64
    bytes = ScaleRb.encode('u256', 18446744073709551616)
    expect(bytes.to_hex).to eql('0x0000000000000000010000000000000000000000000000000000000000000000')

    bytes = ScaleRb.encode('u256', 18446744073709551616)
    o = bytes.each_slice(8).map do |slice|
      ScaleRb.decode('u64', slice).first
    end
    expect(o).to eql([0, 1, 0, 0])
  end
end
