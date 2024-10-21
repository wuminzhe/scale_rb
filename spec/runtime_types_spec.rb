# frozen_string_literal: true

require 'scale_rb'

RSpec.describe ScaleRb::RuntimeTypes do
  let(:hex) { File.read('spec/assets/substrate-metadata-v14-hex').strip }
  let(:runtime_types) { ScaleRb::RuntimeTypes.new(hex) }

  it 'will raise error if metadata version is not v14' do
    hex_v13 = File.read('spec/assets/substrate-metadata-v13-hex').strip
    expect { ScaleRb::RuntimeTypes.new(hex_v13) }.to raise_error(RuntimeError)
  end

  it 'have version' do
    expect(runtime_types.version).to eq(:V14)
  end

  it 'have portable registry' do
    expect(runtime_types.registry.types.length).to eq(696)
  end

  it 'can get a pallet' do
    expect(runtime_types.pallet('System')).not_to be_nil
  end

  it 'can get a pallet by index' do
    expect(runtime_types.pallet_by_index(0)).not_to be_nil
  end

  it 'can get a storage' do
    puts runtime_types.storage('System', 'BlockHash')
    expect(runtime_types.storage('System', 'BlockHash')).not_to be_nil
  end

  it 'can get a call' do
    expect(runtime_types.call_type_id('System', 'remark')).to eql(1)
  end
end
