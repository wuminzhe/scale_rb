require 'scale_rb_2'

RSpec.describe ScaleRb2 do
  it 'has a version number' do
    expect(ScaleRb2::VERSION).not_to be nil
  end

  it 'can correctly decode fixed uint' do
    value, remaining_bytes = ScaleRb2.decode('u8', [0x45])
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb2.decode('u8', [0x45, 0x12])
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([0x12])

    value, remaining_bytes = ScaleRb2.decode('u16', [0x45, 0x00])
    expect(value).to eql(69)
    expect(remaining_bytes).to eql([])

    expect { ScaleRb2.decode('u16', [0x2e]) }.to raise_error(ScaleRb2::NotEnoughBytesError)

    value, remaining_bytes = ScaleRb2.decode('u16', [0x2e, 0xfb])
    expect(value).to eql(64_302)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb2.decode('u16', [0x2e, 0xfb, 0xff])
    expect(value).to eql(64_302)
    expect(remaining_bytes).to eql([0xff])

    value, remaining_bytes = ScaleRb2.decode('u32', [0xff, 0xff, 0xff, 0x00])
    expect(value).to eql(16_777_215)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb2.decode('u64', [0x00, 0xe4, 0x0b, 0x54, 0x03, 0x00, 0x00, 0x00])
    expect(value).to eql(14_294_967_296)
    expect(remaining_bytes).to eql([])

    value, remaining_bytes = ScaleRb2.decode('u128', '0x0bfeffffffffffff0000000000000000'.to_bytes)
    expect(value).to eql(18_446_744_073_709_551_115)
    expect(remaining_bytes).to eql([])
  end

  it 'can correctly encode fixed uint' do
    bytes = ScaleRb2.encode('u8', 69)
    expect(bytes).to eql([0x45])

    bytes = ScaleRb2.encode('u16', 69)
    expect(bytes).to eql([0x45, 0x00])

    bytes = ScaleRb2.encode('u16', 64_302)
    expect(bytes).to eql([0x2e, 0xfb])

    bytes = ScaleRb2.encode('u32', 16_777_215)
    expect(bytes).to eql([0xff, 0xff, 0xff, 0x00])

    bytes = ScaleRb2.encode('u64', 14_294_967_296)
    expect(bytes).to eql('0x00e40b5403000000'.to_bytes)

    bytes = ScaleRb2.encode('u128', 18_446_744_073_709_551_115)
    expect(bytes).to eql('0x0bfeffffffffffff0000000000000000'.to_bytes)
  end

  it 'can correctly decode fixed array' do
    arr, remaining_bytes = ScaleRb2.decode('[u8; 3]', [0x12, 0x34, 0x56, 0x78])
    expect(arr).to eql([0x12, 0x34, 0x56])
    expect(remaining_bytes).to eql([0x78])

    arr, remaining_bytes = ScaleRb2.decode('[u16; 2]', [0x2e, 0xfb, 0x2e, 0xfb])
    expect(arr).to eql([64_302, 64_302])
    expect(remaining_bytes).to eql([])

    arr, remaining_bytes = ScaleRb2.decode('[[u8; 3]; 2]', [0x12, 0x34, 0x56, 0x12, 0x34, 0x56])
    expect(arr).to eql([[0x12, 0x34, 0x56], [0x12, 0x34, 0x56]])
    expect(remaining_bytes).to eql([])

    arr, remaining_bytes = ScaleRb2.decode('[[u16; 2]; 2]', [0x2e, 0xfb, 0x2e, 0xfb, 0x2e, 0xfb, 0x2e, 0xfb])
    expect(arr).to eql([[64_302, 64_302], [64_302, 64_302]])
    expect(remaining_bytes).to eql([])
  end

  it 'can encode fixed array' do
    bytes = ScaleRb2.encode('[u8; 3]', [0x12, 0x34, 0x56])
    expect(bytes).to eql([0x12, 0x34, 0x56])
  end

  it 'can correctly decode single-byte compact uint' do
    value, = ScaleRb2.decode('Compact', [0x00])
    expect(value).to eql(0)

    value, = ScaleRb2.decode('Compact', [0x04])
    expect(value).to eql(1)

    value, = ScaleRb2.decode('Compact', [0xa8])
    expect(value).to eql(42)

    value, = ScaleRb2.decode('Compact', [0xfc])
    expect(value).to eql(63)
  end

  it 'can correctly decode two-byte compact uint' do
    value, = ScaleRb2.decode('Compact', '0x1501'.to_bytes)
    expect(value).to eql(69)
  end

  it 'can correctly decode four-byte compact uint' do
    value, = ScaleRb2.decode('Compact', '0xfeffffff'.to_bytes)
    expect(value).to eql(1_073_741_823)
  end

  it 'can correctly decode big-integer compact uint' do
    value, = ScaleRb2.decode('Compact', '0x0300000040'.to_bytes)
    expect(value).to eql(1_073_741_824)
  end

  it 'can decode struct' do
    struct = {
      item3: 'Compact',
      item1: '[u16; 2]',
      item2: 'Compact'
    }
    bytes = [0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01]
    value, = ScaleRb2.decode(struct, bytes)
    expect(value).to eql({
                           item3: 63,
                           item1: [64_302, 64_302],
                           item2: 69
                         })
  end

  it 'can encode single-byte compact' do
    bytes = ScaleRb2.encode('Compact', 0)
    expect(bytes).to eql([0x00])

    bytes = ScaleRb2.encode('Compact', 1)
    expect(bytes).to eql([0x04])

    bytes = ScaleRb2.encode('Compact', 42)
    expect(bytes).to eql([0xa8])

    bytes = ScaleRb2.encode('Compact', 63)
    expect(bytes).to eql([0xfc])
  end

  it 'can encode two-byte compact' do
    bytes = ScaleRb2.encode('Compact', 69)
    expect(bytes).to eql([0x15, 0x01])
  end

  it 'can encode four-byte compact' do
    bytes = ScaleRb2.encode('Compact', 1_073_741_823)
    expect(bytes).to eql('0xfeffffff'.to_bytes)
  end

  it 'can encode big-integer compact' do
    bytes = ScaleRb2.encode('Compact', 1_073_741_824)
    expect(bytes).to eql('0x0300000040'.to_bytes)
  end

  it 'can encode struct' do
    struct = {
      item3: 'Compact',
      item1: '[u16; 2]',
      item2: 'Compact'
    }
    bytes = ScaleRb2.encode(struct, {
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
    value, = ScaleRb2.decode(enum, bytes)
    expect(value).to eql({
                           Int: 64_302
                         })

    bytes = [0x01, 0x15, 0x01]
    value, = ScaleRb2.decode(enum, bytes)
    expect(value).to eql({
                           Compact: 69
                         })

    expect { ScaleRb2.decode(enum, [0x02, 0x15, 0x01]) }.to raise_error(ScaleRb2::IndexOutOfRangeError)
  end

  it 'can encode enum' do
    enum = {
      _enum: {
        Int: 'u16',
        Compact: 'Compact'
      }
    }
    bytes = ScaleRb2.encode(enum, { Int: 64_302 })
    expect(bytes).to eql([0x00, 0x2e, 0xfb])
  end

  it 'can correctly decode vec' do
    arr, remaining_bytes = ScaleRb2.decode('Vec<u8>', '0x0c003afe'.to_bytes)
    expect(arr).to eql([0, 58, 254])
    expect(remaining_bytes).to eql([])
  end

  it 'can correctly encode vec' do
    bytes = ScaleRb2.encode('Vec<u8>', [0, 58, 254])
    expect(bytes).to eql('0x0c003afe'.to_bytes)
  end

  it 'can correctly decode tuple' do
    value, = ScaleRb2.decode('(Compact, [u16; 2], Compact)', [0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01])
    expect(value).to eql([63, [64_302, 64_302], 69])
  end

  it 'can correctly encode tuple' do
    bytes = ScaleRb2.encode('(Compact, [u16; 2], Compact)', [63, [64_302, 64_302], 69])
    expect(bytes).to eql([0xfc, 0x2e, 0xfb, 0x2e, 0xfb, 0x15, 0x01])
  end

  it 'can correctly decode string' do
    value, = ScaleRb2.decode_string([20, 104, 101, 108, 108, 111])
    expect(value).to eql('hello')

    value, = ScaleRb2.decode_string([24, 228, 189, 160, 229, 165, 189])
    expect(value).to eql('你好')
  end

  it 'can correctly encode string' do
    bytes = ScaleRb2.encode_string('hello')
    expect(bytes).to eql([20, 104, 101, 108, 108, 111])

    bytes = ScaleRb2.encode_string('你好')
    expect(bytes).to eql([24, 228, 189, 160, 229, 165, 189])
  end

  it 'can decode boolean' do
    value, = ScaleRb2.decode('Boolean', [0x00])
    expect(value).to eql(false)

    value, = ScaleRb2.decode('Boolean', [0x01])
    expect(value).to eql(true)

    expect { ScaleRb2.decode('Boolean', [0x02]) }.to raise_error(ScaleRb2::InvalidBytesError)
  end

  it 'can encode boolean' do
    bytes = ScaleRb2.encode('Boolean', false)
    expect(bytes).to eql([0x00])

    bytes = ScaleRb2.encode('Boolean', true)
    expect(bytes).to eql([0x01])

    expect { ScaleRb2.encode('Boolean', nil) }.to raise_error(ScaleRb2::InvalidValueError)
  end
end
