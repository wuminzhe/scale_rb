# frozen_string_literal: true

require 'scale_rb'

# rubocop:disable Metrics/BlockLength
RSpec.describe ScaleRb::Metadata::TypeExp::Tokenizer do
  describe '.tokenize' do
    it 'tokenizes a simple type' do
      tokenizer = described_class.new('A')
      expect(tokenizer.next_token).to eq('A')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['A'])
    end

    it 'tokenizes a generic type' do
      tokenizer = described_class.new('Vec<u8>')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['Vec', '<', 'u8', '>'])
    end

    it 'tokenizes a nested generic type' do
      tokenizer = described_class.new('Vec<Vec<u8>>')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['Vec', '<', 'Vec', '<', 'u8', '>', '>'])
    end

    it 'tokenizes a tuple' do
      tokenizer = described_class.new('(u8, u16)')
      expect(tokenizer.next_token).to eq('(')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq(',')
      expect(tokenizer.next_token).to eq('u16')
      expect(tokenizer.next_token).to eq(')')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['(', 'u8', ',', 'u16', ')'])
    end

    it 'tokenizes an array' do
      tokenizer = described_class.new('[u8; 32]')
      expect(tokenizer.next_token).to eq('[')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq(';')
      expect(tokenizer.next_token).to eq('32')
      expect(tokenizer.next_token).to eq(']')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['[', 'u8', ';', '32', ']'])
    end

    it 'handles double colons' do
      tokenizer = described_class.new('std::vec::Vec')
      expect(tokenizer.next_token).to eq('std')
      expect(tokenizer.next_token).to eq('::')
      expect(tokenizer.next_token).to eq('vec')
      expect(tokenizer.next_token).to eq('::')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['std', '::', 'vec', '::', 'Vec'])
    end

    it 'tokenizes a complex type' do
      complex_type = 'Result<Vec<u8>, Error>'
      expected = ['Result', '<', 'Vec', '<', 'u8', '>', ',', 'Error', '>']
      tokenizer = described_class.new(complex_type)
      expect(tokenizer.next_token).to eq('Result')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.next_token).to eq(',')
      expect(tokenizer.next_token).to eq('Error')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(expected)
    end

    it 'handles whitespace' do
      tokenizer = described_class.new(' Vec < u8 > ')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['Vec', '<', 'u8', '>'])
    end

    it 'tokenizes pointer types' do
      tokenizer = described_class.new('&[u8]')
      expect(tokenizer.next_token).to eq('&')
      expect(tokenizer.next_token).to eq('[')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq(']')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['&', '[', 'u8', ']'])
    end

    it 'tokenizes static lifetime' do
      tokenizer = described_class.new("&'static [u8]")
      expect(tokenizer.next_token).to eq('&')
      expect(tokenizer.next_token).to eq("'")
      expect(tokenizer.next_token).to eq('static')
      expect(tokenizer.next_token).to eq('[')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq(']')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['&', "'", 'static', '[', 'u8', ']'])
    end

    it 'correctly tokenizes simple types' do
      tokenizer = described_class.new('u32')
      expect(tokenizer.next_token).to eq('u32')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['u32'])
    end

    it 'correctly tokenizes types with nested generics' do
      tokenizer = described_class.new('EthHeaderBrief::<T::AccountId>')
      expect(tokenizer.next_token).to eq('EthHeaderBrief')
      expect(tokenizer.next_token).to eq('::')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('T')
      expect(tokenizer.next_token).to eq('::')
      expect(tokenizer.next_token).to eq('AccountId')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['EthHeaderBrief', '::', '<', 'T', '::', 'AccountId', '>'])
    end

    it 'correctly tokenizes complex nested types' do
      tokenizer = described_class.new('Vec<(T::AccountId, Balance)>')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('(')
      expect(tokenizer.next_token).to eq('T')
      expect(tokenizer.next_token).to eq('::')
      expect(tokenizer.next_token).to eq('AccountId')
      expect(tokenizer.next_token).to eq(',')
      expect(tokenizer.next_token).to eq('Balance')
      expect(tokenizer.next_token).to eq(')')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['Vec', '<', '(', 'T', '::', 'AccountId', ',', 'Balance', ')', '>'])
    end

    it 'correctly tokenizes types with multiple nested generics' do
      tokenizer = described_class.new('Result<Vec<u8>, Error<IO>>')
      expect(tokenizer.next_token).to eq('Result')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('Vec')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('u8')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.next_token).to eq(',')
      expect(tokenizer.next_token).to eq('Error')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('IO')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['Result', '<', 'Vec', '<', 'u8', '>', ',', 'Error', '<', 'IO', '>', '>'])
    end

    it 'correctly tokenizes types with trait bounds' do
      tokenizer = described_class.new('<T as Trait<I>>::Type')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('T')
      expect(tokenizer.next_token).to eq('as')
      expect(tokenizer.next_token).to eq('Trait')
      expect(tokenizer.next_token).to eq('<')
      expect(tokenizer.next_token).to eq('I')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.next_token).to eq('>')
      expect(tokenizer.next_token).to eq('::')
      expect(tokenizer.next_token).to eq('Type')
      expect(tokenizer.eof?).to be_truthy
      expect(tokenizer.tokens).to eq(['<', 'T', 'as', 'Trait', '<', 'I', '>', '>', '::', 'Type'])
    end
  end
end
# rubocop:enable Metrics/BlockLength
