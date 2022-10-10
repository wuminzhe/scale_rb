# frozen_string_literal: true

require 'scale_rb'

RSpec.describe ScaleRb do
  it 'get mapped type' do
    registry = {
    }
    type = ScaleRb._get_final_type_from_registry(registry, 'CustomType')
    expect(type).to be(nil)

    registry = {
      'CustomType' => 'Vec<u8>'
    }
    type = ScaleRb._get_final_type_from_registry(registry, 'CustomType')
    expect(type).to eql('Vec<u8>')

    registry = {
      'CustomType' => 'Type1',
      'Type1' => 'Vec<u8>'
    }
    type = ScaleRb._get_final_type_from_registry(registry, 'CustomType')
    expect(type).to eql('Vec<u8>')

    registry = {
      'CustomType' => 'Type1',
      'Type1' => 'Type2',
      'Type2' => 'Vec<u8>'
    }
    type = ScaleRb._get_final_type_from_registry(registry, 'CustomType')
    expect(type).to eql('Vec<u8>')
  end

  it 'decode complex array' do
    registry = {
      'CustomType1' => 'Type1',
      'Type1' => 'u8',
      'CustomType2' => 'u16'
    }
    type = '[([CustomType1; 3], CustomType2); 2]'
    bytes = [
      0x12, 0x34, 0x56, 0x2e, 0xfb,
      0x12, 0x34, 0x56, 0x2e, 0xfb,
      0x78
    ]
    arr, remaining_bytes = ScaleRb.decode(type, bytes, registry)
    expect(arr).to eql([
                         [[0x12, 0x34, 0x56], 64_302],
                         [[0x12, 0x34, 0x56], 64_302]
                       ])
    expect(remaining_bytes).to eql([0x78])
  end

  it 'encode complex array' do
    registry = {
      'CustomType1' => 'Type1',
      'Type1' => 'Compact',
      'CustomType2' => 'u16'
    }
    type = '[([CustomType1; 3], CustomType2); 2]'
    value = [
      [[1, 1_073_741_824, 69], 64_302],
      [[63, 42, 1_073_741_823], 64_302]
    ]
    bytes = ScaleRb.encode(type, value, registry)
    expect(bytes).to eql([
                           0x04, 0x03, 0x00, 0x00, 0x00, 0x40, 0x15, 0x01, 0x2e, 0xfb,
                           0xfc, 0xa8, 0xfe, 0xff, 0xff, 0xff, 0x2e, 0xfb
                         ])
  end

  it 'build registry' do
    config = {
      shared_types: {
        TAssetBalance: 'u128'
      },
      versioned: [
        {
          minmax: 0..3,
          types: {
            DispatchError: 'DispatchErrorPre6First'
          }
        },
        {
          minmax: 4..5,
          types: {
            DispatchError: 'DispatchError'
          }
        },
        {
          minmax: 500..,
          types: {
            DispatchError: 'DispatchErrorAfter'
          }
        }
      ]
    }
    registry = ScaleRb.build_registry_from_config(config, 3)
    expect(registry).to eql({
                              DispatchError: 'DispatchErrorPre6First',
                              TAssetBalance: 'u128'
                            })
    registry = ScaleRb.build_registry_from_config(config, 4)
    expect(registry).to eql({
                              DispatchError: 'DispatchError',
                              TAssetBalance: 'u128'
                            })
    registry = ScaleRb.build_registry_from_config(config, 500)
    expect(registry).to eql({
                              DispatchError: 'DispatchErrorAfter',
                              TAssetBalance: 'u128'
                            })
    registry = ScaleRb.build_registry_from_config(config, 6)
    expect(registry).to eql({
                              TAssetBalance: 'u128'
                            })
  end

  # https://github.com/polkadot-js/api/blob/master/packages/types-support/src/metadata/v14/kusama-json.json
  # https://raw.githubusercontent.com/polkadot-js/api/master/packages/types-support/src/metadata/v14/kusama-types.json
  it 'hello' do
    types = [
      {
        id: 0,
        type: {
          path: %w[
            sp_core
            crypto
            AccountId32
          ],
          params: [],
          def: {
            Composite: {
              fields: [
                {
                  name: nil,
                  type: 1,
                  typeName: '[u8; 32]',
                  docs: []
                }
              ]
            }
          },
          docs: []
        }
      },
      {
        id: 1,
        type: {
          path: [],
          params: [],
          def: {
            Array: {
              len: 32,
              type: 2
            }
          },
          docs: []
        }
      },
      {
        id: 2,
        type: {
          path: [],
          params: [],
          def: {
            Primitive: 'U8'
          },
          docs: []
        }
      }
    ]

    # {
    #   'Array_CustomType1_32' => {
    #     _array: {
    #       len: 32,
    #       type: 'CustomType1'
    #     }
    #   }
    # }
    # {
    #   'FrameSystemAccountInfo' => {
    #     _struct: {
    #
    #     }
    #   }
    # }

    # type_name, type_def = ScaleRb.get_type(types, 0)
    # expect(type_name).to eql('SpCoreCryptoAccountId32')
    # expect(type_def).to eql('[U8; 32]')

    # type_name, type_def = ScaleRb.get_type(types, 2)
    # expect(type_name).to eql('U8')
    # expect(type_def).to eql('U8')
    #
    # type_name, type_def = ScaleRb.get_type(types, 1)
    # expect(type_name).to eql('[U8; 32]')
    # expect(type_def).to eql('U8')
  end
end
