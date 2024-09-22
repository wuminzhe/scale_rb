# frozen_string_literal: true

require 'scale_rb'
require 'json'

module ScaleRb
  RSpec.describe 'Encoding Tests' do
    before(:all) do
      data = JSON.parse(File.open(File.join(__dir__, 'assets', 'substrate-types.json')).read)
      @types = ScaleRb.build_types(data)

      data = JSON.parse(File.open(File.join(__dir__, 'assets', './kusama-types.json')).read)
      @kusama_types = ScaleRb.build_types(data)
    end

    it 'should encode uint' do
      bytes = ScaleRb::Codec.encode 2, 69, @types
      expect(bytes).to eql([0x45])
    end

    it 'should encode array' do
      bytes = ScaleRb::Codec.encode 1,
                                    ScaleRb::Utils.hex_to_u8a('0x1234567812345678123456781234567812345678123456781234567812345678'), @types
      expect(bytes).to eql([0x12, 0x34, 0x56, 0x78] * 8)
    end

    it 'should encode sequence' do
      bytes = ScaleRb::Codec.encode 11, [0, 58, 254], @types
      expect(bytes).to eql(ScaleRb::Utils.hex_to_u8a('0x0c003afe'))
    end

    # ([u8; 32])
    it 'should encode a composite which only has one item without a name' do
      bytes = ScaleRb::Codec.encode 0,
                                    [ScaleRb::Utils.hex_to_u8a('0x1234567812345678123456781234567812345678123456781234567812345678')], @types
      expect(bytes).to eql([0x12, 0x34, 0x56, 0x78] * 8)

      bytes = ScaleRb::Codec.encode 0,
                                    ScaleRb::Utils.hex_to_u8a('0x1234567812345678123456781234567812345678123456781234567812345678'), @types
      expect(bytes).to eql([0x12, 0x34, 0x56, 0x78] * 8)
    end

    it 'should encode composite 1' do
      expect(
        [0x00, 0xe4, 0x0b, 0x54, 0x03, 0x00, 0x00, 0x00]
      ).to eql(
        ScaleRb::Codec.encode(8, { ref_time: 14_294_967_296 }, @types)
      )
    end
  end
end
