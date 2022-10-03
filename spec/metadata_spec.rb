# frozen_string_literal: true

require 'scale_rb'
require 'json'

RSpec.describe Metadata do
  it 'can decode metadata' do
    # TODO: use a mainnet metadata as an example
    # metadata_hex = File.open('./moonbase_metadata').read.strip
    # metadata = Metadata.decode_metadata(metadata_hex.to_bytes)
  end

  it 'can be used to encode storage key' do
  end
end
