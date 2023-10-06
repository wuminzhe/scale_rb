# frozen_string_literal: true

require 'scale_rb'
require 'json'

module ScaleRb
  RSpec.describe StorageHelper do
    before(:all) do
      types = JSON.parse(File.open(File.join(__dir__, 'assets', 'darwinia-types.json')).read)
      @portable_types_registry = types.map { |type| [type['id'], type['type']] }.to_h
    end

    it 'can encode storage key without param' do
      storage_key = StorageHelper.encode_storage_key('System', 'EventCount')
      expect(storage_key).to eql('0x26aa394eea5630e07c48ae0c9558cef70a98fdbe9ce6c55837576c60c7af3850'._to_bytes)
    end

    it 'can encode storage key with one param' do
      # account_id
      key = {
        value: '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'._to_bytes,
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
      expect(storage_key).to eql(expect._to_bytes)
    end

    it 'can encode storage key with two param(same hasher)' do
      storage_key = StorageHelper.encode_storage_key(
        'ImOnline',
        'AuthoredBlocks',
        {
          value: [123, '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'._to_bytes], # U32, AccountId
          type: 291, # 291 => [4, 0]
          hashers: %w[Twox64Concat Twox64Concat]
        },
        @portable_types_registry
      )
      expect = '0x2b06af9719ac64d755623cda8ddd9b94b1c371ded9e9c565e89ba783c4d5f5f92a9a1a82315e68fd7b000000a2c377ff1d6261f6724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'
      expect(storage_key).to eql(expect._to_bytes)
    end

    it 'can encode storage key with two param(different hasher)' do
      storage_key = StorageHelper.encode_storage_key(
        'Multisig',
        'Multisigs',
        {
          value: [
            '0x724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641'._to_bytes, # AccountId
            '0x0101010101010101010101010101010101010101010101010101010101010101'._to_bytes # [U8; 32] array
          ],
          type: 582, # 582 => [0, 1]
          hashers: %w[Twox64Concat Blake2_128Concat]
        },
        @portable_types_registry
      )
      expect = '0x7474449cca95dc5d0c00e71735a6d17d3cd15a3fd6e04e47bee3922dbfa92c8da2c377ff1d6261f6724d50824542b56f422588421643c4a162b90b5416ef063f2266a1eae6651641c035f853fcd0f0589e30c9e2dc1a0f570101010101010101010101010101010101010101010101010101010101010101'
      expect(storage_key).to eql(expect._to_bytes)
    end

    it 'can decode system events' do
      metadata = JSON.parse(File.open(File.join(__dir__, 'assets', 'darwinia-metadata.1243.json')).read)
      data = '0x1800000000000000585f8f09000000000200000001000000040964766d3a000000000000002eabe5c6818731e282b80de1a03f8190426e0dd996404b4c00000000000000000000000000000001000000040764766d3a000000000000002eabe5c6818731e282b80de1a03f8190426e0dd996623116000000000000000000000000000000010000002f009c266c48f07121181d8424768f0ded0170cc63a6044c6030db06afe5c2251138fd7b0c3aef3876f9f60cecfae80a2e3b9cdd3b6d5d810200000000000000000000000000000000000000000000000000000000004b32200000000000000000000000000000000000000000000000000000000000051210db0ddcce0c5a3514e4396b69edac100b112deb966d7a6ee4ab8423edfc779b58f9ed9f96d0c7ba91d11970ea62f7648a7ba440ebacdcc1023c3ba310280cc7239edd250ff23d036d7d9ffc03377346814463d22f3e50fac3179f49a9c30e642c00000100000030002eabe5c6818731e282b80de1a03f8190426e0dd99c266c48f07121181d8424768f0ded0170cc63a6757a2695ae238d39120f2897d6e555b144c90f62ef457009bd83afc1dafc2e6b0000000001000000000080bf490521000000000000'
      storage = StorageHelper.decode_storage3(data, 'System', 'Events', metadata)
      expect =
        [
          {
            phase: { ApplyExtrinsic: 0 },
            event: {
              System: {
                ExtrinsicSuccess: {
                  weight: 160_391_000,
                  class: 'Mandatory',
                  pays_fee: 'Yes'
                }
              }
            },
            topics: []
          },
          {
            phase: { ApplyExtrinsic: 1 },
            event: {
              Balances: {
                Slashed: {
                  who: '0x64766d3a000000000000002eabe5c6818731e282b80de1a03f8190426e0dd996',
                  amount: 5_000_000
                }
              }
            },
            topics: []
          },
          {
            phase: { ApplyExtrinsic: 1 },
            event: {
              Balances: {
                Deposit: {
                  who: '0x64766d3a000000000000002eabe5c6818731e282b80de1a03f8190426e0dd996',
                  amount: 1_454_434
                }
              }
            },
            topics: []
          },
          {
            phase: { ApplyExtrinsic: 1 },
            event: {
              EVM: {
                Log: {
                  log: {
                    address: '0x9c266c48f07121181d8424768f0ded0170cc63a6',
                    topics: ['0x4c6030db06afe5c2251138fd7b0c3aef3876f9f60cecfae80a2e3b9cdd3b6d5d'],
                    data: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 75,
                           50, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 18, 16, 219, 13, 220, 206, 12, 90, 53, 20, 228, 57, 107, 105, 237, 172, 16, 11, 17, 45, 235, 150, 109, 122, 110, 228, 171, 132, 35, 237, 252, 119, 155, 88, 249, 237, 159, 150, 208, 199, 186, 145, 209, 25, 112, 234, 98, 247, 100, 138, 123, 164, 64, 235, 172, 220, 193, 2, 60, 59, 163, 16, 40, 12, 199, 35, 158, 221, 37, 15, 242, 61, 3, 109, 125, 159, 252, 3, 55, 115, 70, 129, 68, 99, 210, 47, 62, 80, 250, 195, 23, 159, 73, 169, 195, 14, 100, 44]
                  }
                }
              }
            },
            topics: []
          },
          {
            phase: { ApplyExtrinsic: 1 },
            event: {
              Ethereum: {
                Executed: {
                  from: '0x2eabe5c6818731e282b80de1a03f8190426e0dd9',
                  to: '0x9c266c48f07121181d8424768f0ded0170cc63a6',
                  transaction_hash: '0x757a2695ae238d39120f2897d6e555b144c90f62ef457009bd83afc1dafc2e6b',
                  exit_reason: {
                    Succeed: 'Stopped'
                  }
                }
              }
            },
            topics: []
          },
          {
            phase: { ApplyExtrinsic: 1 },
            event: { System: { ExtrinsicSuccess: { weight: 141_822_640_000, class: 'Normal', pays_fee: 'Yes' } } },
            topics: []
          }
        ]

      expect(storage).to eql(expect)
    end
  end
end
