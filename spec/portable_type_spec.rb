# frozen_string_literal: true

require 'scale_rb'
require 'json'

module ScaleRb
  RSpec.describe "Type" do

    before(:all) do
      # hex = File.read("./spec/assets/substrate-metadata-v14-hex").strip
      # metadata = ScaleRb::Metadata.decode_metadata(hex)
      # @types = ScaleRb::Metadata.build_registry(metadata)

      data = JSON.parse(File.open(File.join(__dir__, 'assets', 'substrate-types.json')).read)
      @types = ScaleRb.build_types(data)

      data = JSON.parse(File.open(File.join(__dir__, 'assets', './kusama-types.json')).read)
      @kusama_types = ScaleRb.build_types(data)
    end

    it 'can decode fixed uint' do
      value, remaining_bytes = ScaleRb::Codec.decode 2, [0x45], @types
      expect(value).to eql(69)
      expect(remaining_bytes).to eql([])
    end

    it 'can decode array' do
      value, remaining_bytes = ScaleRb::Codec.decode 1, [0x12, 0x34, 0x56, 0x78] * 8 + [0x78], @types
      expect(value).to eql('0x1234567812345678123456781234567812345678123456781234567812345678')
      expect(remaining_bytes).to eql([0x78])
    end

    it 'can decode sequence' do
      value, remaining_bytes = ScaleRb::Codec.decode 11, '0x0c003afe', @types
      expect(value).to eql([0, 58, 254])
      expect(remaining_bytes).to eql([])
    end

    it 'can decode composite 0' do
      value, remaining_bytes = ScaleRb::Codec.decode 0, [0x12, 0x34, 0x56, 0x78] * 8, @types
      expect(value).to eql('0x1234567812345678123456781234567812345678123456781234567812345678')
      expect(remaining_bytes).to eql([])
    end

    it 'can decode composite 1' do
      bytes = [0x00, 0xe4, 0x0b, 0x54, 0x03, 0x00, 0x00, 0x00]
      value, = ScaleRb::Codec.decode 8, bytes, @types
      expect(
        value
      ).to eql(
        {
          ref_time: 14_294_967_296
        }
      )
    end

    it 'can decode composite 2' do
      bytes = '0x'\
        '05000000000000000100000000000000142ba3d4e80000000000000000000000'\
        '0000000000000000000000000000000000000000000000000000000000000000'\
        '00000000000000000000000000000000'
      value, = ScaleRb::Codec.decode 3, bytes, @types
      expect(
        value
      ).to eql(
        {
          nonce: 5,
          consumers: 0,
          providers: 1,
          sufficients: 0,
          data: {
            free: 999_999_875_860,
            reserved: 0,
            misc_frozen: 0,
            fee_frozen: 0
          }
        }
      )
    end

    it 'can decode composite4' do
      bytes = '0x'\
        '020406010700f2052a017d01260000400d030000000000000000000000000000'\
        '00000000000000000000000000000001004617d470f847ce166019d19a794404'\
        '9ebb017400000000000000000000000000000000000000000000000000000000'\
        '00000000001019ff1d2100'
      value, = ScaleRb::Codec.decode 542, bytes, @kusama_types
      expect =
        {
          V2: [
            {
              Transact: {
                origin_type: 'SovereignAccount',
                require_weight_at_most: 5_000_000_000,
                call: {
                  encoded: [
                    38, 0, 0, 64, 13, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 1, 0, 70, 23, 212, 112, 248, 71, 206, 22, 96, 25, 209, 154, 121, 68, 4, 158, 187,
                    1, 116, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 16, 25, 255, 29, 33, 0
                  ]
                }
              }
            }
          ]
        }
      expect(value).to eql(expect)
    end

    it 'can decode unit' do
      value, = ScaleRb::Codec.decode 161, [], @types
      expect(value).to eql([])
    end

  end
end
