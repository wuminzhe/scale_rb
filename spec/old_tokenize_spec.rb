# frozen_string_literal: true

require_relative '../lib/types/build_types_from_registry'

# rubocop:disable Metrics/BlockLength
RSpec.describe ScaleRb::TypeExp::TypeExpParser do
  describe '.tokenize' do
    it 'tokenizes a simple named type' do
      expect(described_class.tokenize('Vec')).to eq(['Vec'])
    end

    it 'tokenizes a generic type' do
      expect(described_class.tokenize('Vec<u8>')).to eq(['Vec', '<', 'u8', '>'])
    end

    it 'tokenizes a nested generic type' do
      expect(described_class.tokenize('Vec<Vec<u8>>')).to eq(['Vec', '<', 'Vec', '<', 'u8', '>', '>'])
    end

    it 'tokenizes a tuple' do
      expect(described_class.tokenize('(u8, u16)')).to eq(['(', 'u8', ',', 'u16', ')'])
    end

    it 'tokenizes an array' do
      expect(described_class.tokenize('[u8; 32]')).to eq(['[', 'u8', ';', '32', ']'])
    end

    it 'handles double colons' do
      expect(described_class.tokenize('std::vec::Vec')).to eq(['std', '::', 'vec', '::', 'Vec'])
    end

    it 'tokenizes a complex type' do
      complex_type = 'Result<Vec<u8>, Error>'
      expected = ['Result', '<', 'Vec', '<', 'u8', '>', ',', 'Error', '>']
      expect(described_class.tokenize(complex_type)).to eq(expected)
    end

    it 'handles whitespace' do
      expect(described_class.tokenize(' Vec < u8 > ')).to eq(['Vec', '<', 'u8', '>'])
    end

    it 'tokenizes pointer types' do
      expect(described_class.tokenize('&[u8]')).to eq(['&', '[', 'u8', ']'])
    end

    it 'tokenizes static lifetime' do
      expect(described_class.tokenize("&'static [u8]")).to eq(['&', "'", 'static', '[', 'u8', ']'])
    end

    it 'correctly tokenizes simple types' do
      expect(described_class.tokenize('u32')).to eq(['u32'])
    end

    it 'correctly tokenizes types with double colons' do
      expect(described_class.tokenize('std::vec::Vec')).to eq(['std', '::', 'vec', '::', 'Vec'])
    end

    it 'correctly tokenizes complex types' do
      expect(described_class.tokenize('Vec<u8>')).to eq(['Vec', '<', 'u8', '>'])
    end

    it 'correctly tokenizes types with single quotes' do
      expect(described_class.tokenize("&'static [u8]")).to eq(['&', "'", 'static', '[', 'u8', ']'])
    end

    it 'correctly tokenizes tuple types' do
      expect(described_class.tokenize('(u32, bool)')).to eq(['(', 'u32', ',', 'bool', ')'])
    end

    # EthHeaderBrief::<T::AccountId>
    it 'correctly tokenizes types with nested generics' do
      expect(described_class.tokenize('EthHeaderBrief::<T::AccountId>')).to eq(
        ['EthHeaderBrief', '::', '<', 'T', '::', 'AccountId', '>']
      )
    end
  end
end
# rubocop:enable Metrics/BlockLength
