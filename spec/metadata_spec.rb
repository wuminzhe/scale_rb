# frozen_string_literal: true

require 'scale_rb'
require 'json'

# https://github.com/polkadot-js/api/tree/master/packages/types-support/src/metadata
def expect_decode_metadata(version)
  hex = File.read("./spec/assets/substrate-metadata-#{version}-hex").strip
  metadata = Metadata.decode_metadata(hex.to_bytes)
  expect(metadata[:metadata][version.to_sym]).not_to be_nil
end

def expect_get_storage_item(version)
  hex = File.read("./spec/assets/substrate-metadata-#{version}-hex").strip
  metadata = Metadata.decode_metadata(hex.to_bytes)
  storage_item = Metadata.const_get("Metadata#{version.upcase}").get_storage_item('System', 'BlockHash', metadata)
  expect(storage_item).not_to be_nil
end

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
end
