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

    it 'can get pallet call type' do
      remark_type_id = @metadata.pallet_call_type_id('System', 'remark')
      expect(remark_type_id).to eql(12)
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
  end
end
