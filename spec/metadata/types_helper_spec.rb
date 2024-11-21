# frozen_string_literal: true

require 'scale_rb'

RSpec.describe ScaleRb::Metadata::TypesHelper do
  let(:yaml_path) { './spec/assets/polkadot_types.yaml' }

  describe '.build_types' do
    it 'loads basic types from global section' do
      types = described_class.build_types(22, yaml_path)
      
      # Test a simple string type
      expect(types['Balance']).to eq('u128')
      
      # Test a hash type
      expect(types['AccountInfo<Index, AccountData>']).to eq({
        'nonce' => 'Index',
        'refcount' => 'RefCount',
        'data' => 'AccountData'
      })
      
      # Test an enum type
      expect(types['Phase']).to eq({
        '_enum' => {
          'ApplyExtrinsic' => 'u32',
          'Finalization' => [],
          'Initialization' => []
        }
      })
    end

    context 'with spec version specific overrides' do
      it 'applies overrides for spec version 25' do
        types = described_class.build_types(25, yaml_path)
        expect(types['RefCount']).to eq('u32')
      end

      it 'applies overrides for spec version 28' do
        types = described_class.build_types(28, yaml_path)
        
        # Test that ValidatorPrefs was updated
        expect(types['ValidatorPrefs']).to eq({
          'commission' => 'Compact<Perbill>',
          'blocked' => 'bool'
        })

        # Test that AccountInfo was updated
        expect(types['AccountInfo<Index, AccountData>']).to eq({
          'nonce' => 'Index',
          'consumers' => 'RefCount',
          'providers' => 'RefCount',
          'data' => 'AccountData'
        })
      end

      it 'applies overrides for spec version 30' do
        types = described_class.build_types(30, yaml_path)
        
        # Test that AccountInfo was updated again
        expect(types['AccountInfo<Index, AccountData>']).to eq({
          'nonce' => 'Index',
          'consumers' => 'RefCount',
          'providers' => 'RefCount',
          'sufficients' => 'RefCount',
          'data' => 'AccountData'
        })
      end
    end

    context 'with complex type definitions' do
      it 'handles nested types correctly' do
        types = described_class.build_types(22, yaml_path)
        
        expect(types['EventRecord<Event, Hash>']).to eq({
          'phase' => 'Phase',
          'event' => 'Event',
          'topics' => 'Vec<Hash>'
        })
      end

      it 'handles array types correctly' do
        types = described_class.build_types(22, yaml_path)
        
        expect(types['LockIdentifier']).to eq('[u8; 8]')
      end
    end
  end
end 