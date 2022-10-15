# frozen_string_literal: true

require 'scale_rb'
require 'json'

RSpec.describe StorageHelper do
  before(:all) do
    types = JSON.parse(File.open(File.join(__dir__, 'assets', 'darwinia-types.json')).read)
    @portable_types_registry = types.map { |type| [type['id'], type['type']] }.to_h
  end

  it 'can encode storage key without param' do
    storage_key = StorageHelper.encode_storage_key('System', 'EventCount')
    expect(storage_key).to eql('0x26aa394eea5630e07c48ae0c9558cef70a98fdbe9ce6c55837576c60c7af3850'.to_bytes)
  end

  it 'can encode storage key with one param' do
    # account_id
    key = {
      value: '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'.to_bytes,
      type: 0,
      hashers: ['Blake2_128Concat']
    }

    storage_key = StorageHelper.encode_storage_key(
      'System',
      'Account',
      key,
      @portable_types_registry
    )
    expect = '0x26aa394eea5630e07c48ae0c9558cef7b99d880ec681799c0cf30e8886371da94bab0fcfc536fa263f3b241cd32f76a8724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'
    expect(storage_key).to eql(expect.to_bytes)
  end

  it 'can encode storage key with two param(same hasher)' do
    storage_key = StorageHelper.encode_storage_key(
      'ImOnline',
      'AuthoredBlocks',
      {
        value: [123, '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'.to_bytes], # U32, AccountId
        type: 291, # 291 => [4, 0]
        hashers: %w[Twox64Concat Twox64Concat]
      },
      @portable_types_registry
    )
    expect = '0x2b06af9719ac64d755623cda8ddd9b94b1c371ded9e9c565e89ba783c4d5f5f92a9a1a82315e68fd7b000000a2c377ff1d6261f6724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'
    expect(storage_key).to eql(expect.to_bytes)
  end

  it 'can encode storage key with two param(different hasher)' do
    storage_key = StorageHelper.encode_storage_key(
      'Multisig',
      'Multisigs',
      {
        value: [
          '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'.to_bytes, # AccountId
          '0x0101010101010101010101010101010101010101010101010101010101010101'.to_bytes # [U8; 32] array
        ],
        type: 582, # 582 => [0, 1]
        hashers: %w[Twox64Concat Blake2_128Concat]
      },
      @portable_types_registry
    )
    expect = '0x7474449cca95dc5d0c00e71735a6d17d3cd15a3fd6e04e47bee3922dbfa92c8da2c377ff1d6261f6724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641c035f853fcd0f0589e30c9e2dc1a0f570101010101010101010101010101010101010101010101010101010101010101'
    expect(storage_key).to eql(expect.to_bytes)
  end
end
