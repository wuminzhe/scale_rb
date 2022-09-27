# frozen_string_literal: true

require 'scale_rb_2'
require 'json'

RSpec.describe ScaleRb2 do
  it 'can decode metadata' do
    # TODO: use a mainnet metadata as an example
    metadata_hex = File.open('./moonbase_metadata').read.strip
    metadata = ScaleRb2.decode_metadata(metadata_hex.to_bytes)
  end
end
