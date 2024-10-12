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
        @metadata = ScaleRb::Metadata.decode_metadata(hex)
      end
      puts "Decoding metadata v14: #{time.real / 60} minutes"
    end

    it 'can decode metadata v14' do
      expect(@metadata[:magicNumber]).to eq(1_635_018_093)
    end

    it 'can get storage item from metadata v14' do
      storage_item = ScaleRb::Metadata.get_storage_item('System', 'BlockHash', @metadata)
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
      system_module = ScaleRb::Metadata.get_module('System', @metadata)
      expect(system_module.keys).to eql(%i[name storage calls events constants errors index])
      expect(system_module[:name]).to eql('System')
      expect(system_module[:calls]).to eql({ type: 141 })
      expect(system_module[:index]).to eql(0)
    end

    it 'can get module by index' do
      system_module = ScaleRb::Metadata.get_module_by_index(0, @metadata)
      expect(system_module.keys).to eql(%i[name storage calls events constants errors index])
    end

    it 'can get calls type' do
      calls_type = ScaleRb::Metadata.get_calls_type('System', @metadata)
      expect(calls_type).to eql(
        {
          id: 141,
          type: {
            path: %w[frame_system pallet Call],
            params: [{ name: 'T', type: nil }],
            def: {
              variant: {
                variants: [
                  {
                    name: 'fill_block',
                    fields: [{ name: 'ratio', type: 45, typeName: 'Perbill', docs: [] }],
                    index: 0,
                    docs: ['A dispatch that will fill the block weight up to the given ratio.']
                  },
                  {
                    name: 'remark',
                    fields: [{ name: 'remark', type: 12, typeName: 'Vec<u8>', docs: [] }],
                    index: 1,
                    docs: [
                      'Make some on-chain remark.',
                      '',
                      '# <weight>',
                      '- `O(1)`',
                      '# </weight>'
                    ]
                  },
                  {
                    name: 'set_heap_pages',
                    fields: [{ name: 'pages', type: 10, typeName: 'u64', docs: [] }],
                    index: 2,
                    docs: ["Set the number of pages in the WebAssembly environment's heap."]
                  },
                  {
                    name: 'set_code',
                    fields: [{ name: 'code', type: 12, typeName: 'Vec<u8>', docs: [] }],
                    index: 3,
                    docs: [
                      'Set the new runtime code.',
                      '',
                      '# <weight>',
                      '- `O(C + S)` where `C` length of `code` and `S` complexity of `can_set_code`',
                      '- 1 call to `can_set_code`: `O(S)` (calls `sp_io::misc::runtime_version` which is',
                      '  expensive).',
                      '- 1 storage write (codec `O(C)`).',
                      '- 1 digest item.',
                      '- 1 event.',
                      'The weight of this function is dependent on the runtime, but generally this is very',
                      'expensive. We will treat this as a full block.',
                      '# </weight>'
                    ]
                  },
                  {
                    name: 'set_code_without_checks',
                    fields: [{ name: 'code', type: 12, typeName: 'Vec<u8>', docs: [] }],
                    index: 4,
                    docs: [
                      'Set the new runtime code without doing any checks of the given `code`.',
                      '',
                      '# <weight>',
                      '- `O(C)` where `C` length of `code`',
                      '- 1 storage write (codec `O(C)`).',
                      '- 1 digest item.',
                      '- 1 event.',
                      'The weight of this function is dependent on the runtime. We will treat this as a full', 'block. # </weight>'
                    ]
                  },
                  { name: 'set_storage', fields: [{ name: 'items', type: 142, typeName: 'Vec<KeyValue>', docs: [] }],
                    index: 5, docs: ['Set some items of storage.'] },
                  { name: 'kill_storage', fields: [{ name: 'keys', type: 144, typeName: 'Vec<Key>', docs: [] }],
                    index: 6, docs: ['Kill some items from storage.'] },
                  { name: 'kill_prefix',
                    fields: [{ name: 'prefix', type: 12, typeName: 'Key', docs: [] }, { name: 'subkeys', type: 4, typeName: 'u32', docs: [] }], index: 7, docs: ['Kill all storage items with a key that starts with the given prefix.', '', '**NOTE:** We rely on the Root origin to provide us the number of subkeys under', 'the prefix we are removing to accurately calculate the weight of this function.'] },
                  { name: 'remark_with_event', fields: [{ name: 'remark', type: 12, typeName: 'Vec<u8>', docs: [] }],
                    index: 8, docs: ['Make some on-chain remark and emit event.'] }
                ]
              }
            },
            docs: ['Contains one variant per dispatchable that can be called by an extrinsic.']
          }
        }
      )
    end

    it 'can get call type' do
      call_type = ScaleRb::Metadata.get_call_type('System', 'remark', @metadata)
      expect(call_type).to eql(
        {
          name: 'remark',
          fields: [{ name: 'remark', type: 12, typeName: 'Vec<u8>', docs: [] }],
          index: 1,
          docs: [
            'Make some on-chain remark.',
            '',
            '# <weight>',
            '- `O(1)`',
            '# </weight>'
          ]
        }
      )
    end

    it 'can build registry from its lookup' do
      registry = ScaleRb::Metadata.build_registry(@metadata)
      expect(registry.types.length).to eq(696)
    end
  end
end
