# frozen_string_literal: true

require 'scale_rb'

RSpec.describe ScaleRb::RuntimeSpec do
  let(:hex) { File.read('spec/assets/substrate-metadata-v14-hex').strip }
  let(:runtime_spec) { ScaleRb::RuntimeSpec.new(hex) }

  it 'have version' do
    expect(runtime_spec.version).to eq(:V14)
  end

  it 'have portable registry' do
    expect(runtime_spec.portable_registry.types.length).to eq(696)
  end
end
