# frozen_string_literal: true

require 'scale_rb'
require 'json'

# https://github.com/polkadot-js/api/tree/master/packages/types-support/src/metadata
def expect_decode_metadata(version)
  hex = File.read("./spec/assets/substrate-metadata-#{version}-hex").strip
  metadata = ScaleRb::Metadata.decode_metadata(hex._to_bytes)
  expect(metadata[:metadata][version.to_sym]).not_to be_nil
end

def expect_get_storage_item(version)
  hex = File.read("./spec/assets/substrate-metadata-#{version}-hex").strip
  metadata = ScaleRb::Metadata.decode_metadata(hex._to_bytes)
  storage_item = ScaleRb::Metadata.const_get("Metadata#{version.upcase}").get_storage_item(
    'System', 'BlockHash',
    metadata
  )
  expect(storage_item).not_to be_nil
end

module ScaleRb
  RSpec.describe Metadata do
    it 'can decode metadata v9 ~ v14' do
      (9..14).each do |i|
        expect_decode_metadata("v#{i}")
      end
    end

    it 'can get storage item from metadata v9 ~ v14' do
      (9..14).each do |i|
        expect_get_storage_item("v#{i}")
      end
    end

    it 'can get call type' do
      metadata = JSON.parse(File.open(File.join(__dir__, 'assets', './pangolin2.json')).read)

      call_type = Metadata.get_call_type('PolkadotXcm', 'Execute', metadata)
      expect(call_type).to eql({ 'name' => 'execute',
                                 'fields' => [{ 'name' => 'message', 'type' => 394, 'typeName' => 'Box<VersionedXcm<<T as SysConfig>::RuntimeCall>>', 'docs' => [] }, { 'name' => 'max_weight', 'type' => 8, 'typeName' => 'Weight', 'docs' => [] }], 'index' => 3, 'docs' => ['Execute an XCM message from a local, signed, origin.', '', 'An event is deposited indicating whether `msg` could be executed completely or only', 'partially.', '', 'No more than `max_weight` will be used in its attempted execution. If this is less than the', 'maximum amount of weight that the message could take to be executed, then no execution', 'attempt will be made.', '', 'NOTE: A successful return to this does *not* imply that the `msg` was executed successfully', 'to completion; only that *some* of it was executed.'] })
    end
  end
end
