# frozen_string_literal: true

require 'scale_rb'

module ScaleRb
  RSpec.describe Hasher do
    it 'can hash with twox128' do
      expect(Hasher.twox128('System')).to eql(Utils.hex_to_u8a('26aa394eea5630e07c48ae0c9558cef7'))
      expect(Hasher.twox128('Account')).to eql(Utils.hex_to_u8a('b99d880ec681799c0cf30e8886371da9'))
    end

    it 'can hash with Blake2128Concat' do
      result = Hasher.apply_hasher('Blake2128Concat',
                                   '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641')
      expect(result).to eql(
        Utils.hex_to_u8a('4bab0fcfc536fa263f3b241cd32f76a8724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641')
      )

      result = Hasher.apply_hasher('Blake2_128Concat',
                                   '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641')
      expect(result).to eql(
        Utils.hex_to_u8a('4bab0fcfc536fa263f3b241cd32f76a8724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641')
      )
    end

    it 'can hash with Twox64Concat' do
      result = Hasher.apply_hasher('Twox64Concat', ScaleRb.encode('u32', 123))
      expect(result).to eql(Utils.hex_to_u8a('2a9a1a82315e68fd7b000000'))

      result = Hasher.apply_hasher('Twox64Concat', ScaleRb.encode('u32', 235_890_454))
      expect(result).to eql(Utils.hex_to_u8a('01231bfbf9d42fd916670f0e'))
    end

    it 'can hash with Identity' do
      result = Hasher.apply_hasher('Identity', ScaleRb.encode('u32', 123))
      expect(result).to eql(ScaleRb.encode('u32', 123))
    end
  end
end
