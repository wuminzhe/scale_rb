# frozen_string_literal: true

require 'scale_rb'
require 'json'

module ScaleRb
  RSpec.describe CallHelper do
    it 'can decode call' do
      metadata = JSON.parse(
        File.read('./spec/assets/pangolin2.json'),
        symbolize_names: true
      )

      callbytes = Utils.hex_to_u8a('0x0901')
      decoded = CallHelper.decode_call(callbytes, metadata)
      expect(decoded).to eql({ pallet_name: 'Deposit', call_name: 'claim', call: :claim })

      callbytes = Utils.hex_to_u8a('0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798')
      decoded = CallHelper.decode_call(callbytes, metadata)
      expect(decoded).to eql(
        {
          pallet_name: 'Balances',
          call_name: 'transfer',
          call: {
            transfer: {
              dest: Utils.hex_to_u8a('0x0a1287977578f888bdc1c7627781af1cc000e6ab'),
              value: 11_000_000_000_000_000_000
            }
          }
        }
      )

      callbytes = Utils.hex_to_u8a('0x2c000120a1070000000000000000000000000000000000000000000000000000000000005a07db2bd2624dd2bdd5093517048a0033a615b50000e8890423c78a000000000000000000000000000000000000000000000000901003e2d2000000000000000000000000000000000000000000000000000000000000000200')
      decoded = CallHelper.decode_call(callbytes, metadata)
      expect(decoded).to eql(
        {
          pallet_name: 'EthereumXcm',
          call_name: 'transact',
          call: {
            transact: {
              xcm_transaction: {
                V2: {
                  gas_limit: [500_000, 0, 0, 0],
                  action: {
                    Call: Utils.hex_to_u8a('0x5a07db2bd2624dd2bdd5093517048a0033a615b5')
                  },
                  value: [10_000_000_000_000_000_000, 0, 0, 0],
                  input: [16, 3, 226, 210, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0, 0, 2],
                  access_list: nil
                }
              }
            }
          }
        }
      )
    end

    it 'can encode call' do
      metadata = JSON.parse(
        File.read('./spec/assets/pangolin2.json'),
        symbolize_names: true
      )

      call = { pallet_name: 'Deposit', call_name: 'claim', call: :claim }
      encoded = CallHelper.encode_call(call, metadata)
      expect(encoded).to eql([9, 1])

      call = {
        pallet_name: 'Balances',
        call_name: 'transfer',
        call: {
          transfer: {
            dest: [10, 18, 135, 151, 117, 120, 248, 136, 189, 193, 199, 98, 119, 129, 175, 28, 192, 0, 230, 171],
            value: 11_000_000_000_000_000_000
          }
        }
      }
      encoded = CallHelper.encode_call(call, metadata)
      expect(encoded).to eql(Utils.hex_to_u8a('0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798'))

      call = {
        pallet_name: 'EthereumXcm',
        call_name: 'transact',
        call: {
          transact: {
            xcm_transaction: {
              V2: {
                gas_limit: [500_000, 0, 0, 0],
                action: {
                  Call: [90, 7, 219, 43, 210, 98, 77, 210, 189, 213, 9, 53, 23, 4, 138, 0, 51, 166, 21, 181]
                },
                value: [10_000_000_000_000_000_000, 0, 0, 0],
                input: [16, 3, 226, 210, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 2],
                access_list: nil
              }
            }
          }
        }
      }
      encoded = CallHelper.encode_call(call, metadata)
      expect(encoded).to eql(Utils.hex_to_u8a('0x2c000120a1070000000000000000000000000000000000000000000000000000000000005a07db2bd2624dd2bdd5093517048a0033a615b50000e8890423c78a000000000000000000000000000000000000000000000000901003e2d2000000000000000000000000000000000000000000000000000000000000000200'))
    end
  end
end
