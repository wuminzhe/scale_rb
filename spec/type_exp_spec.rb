# frozen_string_literal: true

require 'scale_rb'

RSpec.describe ScaleRb::Metadata::TypeExp do
  def self.ast(exp, type)
    it "AST: #{exp}" do
      parsed = described_class.parse(exp)
      expect(parsed.to_s).to eq(type.to_s)
    end
  end

  def self.test(exp, result = nil)
    it result ? "#{exp} -> #{result}" : exp do
      type = described_class.parse(exp)
      printed = described_class.print(type)
      expect(printed).to eq(result || exp)
    end
  end

  describe 'AST parsing' do
    ast('A', ScaleRb::Metadata::TypeExp::NamedType.new('A', []))

    ast('Vec<u8>',
        ScaleRb::Metadata::TypeExp::NamedType.new('Vec', [ScaleRb::Metadata::TypeExp::NamedType.new('u8', [])]))

    ast('[A; 10]',
        ScaleRb::Metadata::TypeExp::ArrayType.new(ScaleRb::Metadata::TypeExp::NamedType.new('A', []), 10))

    ast('[u8; 16; H128]',
        ScaleRb::Metadata::TypeExp::ArrayType.new(ScaleRb::Metadata::TypeExp::NamedType.new('u8', []), 16))

    ast(
      '(A, B, [u8; 5])',
      ScaleRb::Metadata::TypeExp::TupleType.new(
        [
          ScaleRb::Metadata::TypeExp::NamedType.new('A', []),
          ScaleRb::Metadata::TypeExp::NamedType.new(
            'B', []
          ),
          ScaleRb::Metadata::TypeExp::ArrayType.new(
            ScaleRb::Metadata::TypeExp::NamedType.new(
              'u8', []
            ), 5
          )
        ]
      )
    )
  end

  describe 'Parsing and printing' do
    test('A')
    test('Text')
    test('Vec<u8>')
    test('[A; 20]')
    test('(A, B, C, [Foo; 5])')
    test('Vec<(NominatorIndex, [CompactScore; 0], ValidatorIndex)>')
    test('Result<(), DispatchError>')

    test('<T::InherentOfflineReport as InherentOfflineReport>::Inherent', 'InherentOfflineReport')
    test('<T::Balance as HasCompact>', 'Compact<Balance>')
    test('<T as Trait<I>>::Proposal', 'Proposal')
    test('rstd::marker::PhantomData<(AccountId, Event)>', 'PhantomData<(AccountId, Event)>')

    test(
      'Vec<(T::AccountId,<<T as pallet_proxy::Config>::Currency as frame_support::traits::Currency<<T as frame_system::Config>::AccountId,>>::Balance, (BoundedVec<ProxyDefinition<T::AccountId, T::ProxyType, T::BlockNumber>,<T as pallet_proxy::Config>::MaxProxies,>,<<T as pallet_proxy::Config>::Currency as frame_support::traits::Currency<<T as frame_system::Config>::AccountId,>>::Balance,),)>',
      'Vec<(AccountId, Balance, (BoundedVec<ProxyDefinition<AccountId, ProxyType, BlockNumber>, MaxProxies>, Balance))>'
    )

    test('EthHeaderBrief::<T::AccountId>', 'EthHeaderBrief<AccountId>')
  end
end
