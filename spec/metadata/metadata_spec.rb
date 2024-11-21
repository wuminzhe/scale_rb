# frozen_string_literal: true

require 'scale_rb'
require 'json'

# ENABLE_TYPE_ENFORCEMENT=true TYPE_ENFORCEMENT_LEVEL=0 rspec ./spec/metadata_spec.rb
# Note: enable type checking will cause performance issue.

# https://github.com/polkadot-js/api/tree/master/packages/types-support/src/metadata
module ScaleRb
  RSpec.describe Metadata do
    before(:all) do
      hex = File.read('./spec/assets/substrate-metadata-v14-hex').strip
      time = Benchmark.measure do
        @metadata = ScaleRb::Metadata::Metadata.from_hex(hex)
      end
      puts "Decoding metadata v14: #{time.real / 60} minutes"
    end

    it 'can decode metadata v14' do
      expect(@metadata.magic_number).to eq(1_635_018_093)
    end

    it 'can get storage item from metadata v14' do
      storage_item = @metadata.storage('System', 'BlockHash')
      expect(storage_item).to eql(
        {
          name: 'BlockHash',
          modifier: :Default,
          type: { map: { hashers: [:Twox64Concat], key: 4, value: 11 } },
          fallback: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0],
          docs: [' Map of block numbers to block hashes.']
        }
      )
    end

    it 'can get module by name' do
      system_module = @metadata.pallet('System')
      expect(system_module.keys).to eql(%i[name storage calls events constants errors index])
      expect(system_module[:name]).to eql('System')
      expect(system_module[:calls]).to eql({ type: 141 })
      expect(system_module[:index]).to eql(0)
    end

    it 'can get module by index' do
      system_module = @metadata.pallet_by_index(0)
      expect(system_module.keys).to eql(%i[name storage calls events constants errors index])
    end

    it 'can get call type' do
      call_type = @metadata.call_type('System', 'remark')
      expect(call_type).to be_a(ScaleRb::Types::StructType)
      expect(call_type.fields.size).to eql(1)
      expect(call_type.fields[0].name).to eql('remark')
      expect(call_type.fields[0].type).to eql(12)
    end

    it 'can get unchecked extrinsic type id' do
      expect(@metadata.unchecked_extrinsic_type_id).to eql(681)
      expect(@metadata.address_type_id).to eql(174)
      expect(@metadata.call_type_id).to eql(159)
      expect(@metadata.extrinsic_signature_type_id).to eql(682)

      expect(@metadata.digest_type_id).to eql(13)
      expect(@metadata.digest_item_type_id).to eql(15)

      expect(@metadata.event_record_list_type_id).to eql(17)
      expect(@metadata.event_record_type_id).to eql(18)
      expect(@metadata.event_type_id).to eql(19)

      expect(@metadata.signature_type_id).to eql(@metadata.registry.types.size - 1)
    end

    # it 'can get signature type' do
    #   expect = [
    #     { identifier: 'CheckNonZeroSender', type: 686, additionalSigned: 31 },
    #     { identifier: 'CheckSpecVersion', type: 687, additionalSigned: 4 },
    #     { identifier: 'CheckTxVersion', type: 688, additionalSigned: 4 },
    #     { identifier: 'CheckGenesis', type: 689, additionalSigned: 11 },
    #     { identifier: 'CheckMortality', type: 690, additionalSigned: 11 },
    #     { identifier: 'CheckNonce', type: 692, additionalSigned: 31 },
    #     { identifier: 'CheckWeight', type: 693, additionalSigned: 31 },
    #     { identifier: 'ChargeAssetTxPayment', type: 694, additionalSigned: 31 }
    #   ]
    #   expect(ScaleRb::Metadata.signed_extensions_type(@metadata)).to eq(expect)
    # end
  end
end
