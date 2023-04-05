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
  it 'can decode call' do
    metadata = JSON.parse(
      File.read("./spec/assets/pangolin2.json")
    )

    callbytes = "0x0901".to_bytes
    decoded = Metadata.decode_call(callbytes, metadata)
    expect(decoded).to eql({:pallet_name=>"Deposit", :call_name=>"Claim", :call=>["claim", []]})

    callbytes = "0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798".to_bytes
    decoded = Metadata.decode_call(callbytes, metadata)
    expect(decoded).to eql({:pallet_name=>"Balances", :call_name=>"Transfer", :call=>[{:transfer=>{:dest=>[10, 18, 135, 151, 117, 120, 248, 136, 189, 193, 199, 98, 119, 129, 175, 28, 192, 0, 230, 171], :value=>11000000000000000000}}, []]})

    callbytes = "0x2c000120a1070000000000000000000000000000000000000000000000000000000000005a07db2bd2624dd2bdd5093517048a0033a615b50000e8890423c78a000000000000000000000000000000000000000000000000901003e2d2000000000000000000000000000000000000000000000000000000000000000200".to_bytes
    decoded = Metadata.decode_call(callbytes, metadata)
    expect(decoded).to eql(
      {
        :pallet_name=>"EthereumXcm", 
        :call_name=>"Transact", 
        :call=>[
          {
            :transact=>{
              :xcm_transaction=>{
                :V2=>{
                  :gas_limit=>[500000, 0, 0, 0], 
                  :action=>{
                    :Call=>[90, 7, 219, 43, 210, 98, 77, 210, 189, 213, 9, 53, 23, 4, 138, 0, 51, 166, 21, 181]
                  }, 
                  :value=>[10000000000000000000, 0, 0, 0], 
                  :input=>[16, 3, 226, 210, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2], 
                  :access_list=>"None"
                }
              }
            }
          }, 
          []
        ]
      }
    )
  end

  it 'can encode call' do
    metadata = JSON.parse(
      File.read("./spec/assets/pangolin2.json")
    )

    call = {:pallet_name=>"Deposit", :call_name=>"Claim", :call=>["claim", []]}
    encoded = Metadata.encode_call(call, metadata)
    expect(encoded).to eql("0x0901".to_bytes)

    call = {:pallet_name=>"Balances", :call_name=>"Transfer", :call=>[{:transfer=>{:dest=>[10, 18, 135, 151, 117, 120, 248, 136, 189, 193, 199, 98, 119, 129, 175, 28, 192, 0, 230, 171], :value=>11000000000000000000}}, []]}
    encoded = Metadata.encode_call(call, metadata)
    expect(encoded).to eql("0x05000a1287977578f888bdc1c7627781af1cc000e6ab1300004c31b8d9a798".to_bytes)

    call = {
      :pallet_name=>"EthereumXcm", 
      :call_name=>"Transact", 
      :call=>[
        {
          :transact=>{
            :xcm_transaction=>{
              :V2=>{
                :gas_limit=>[500000, 0, 0, 0], 
                :action=>{
                  :Call=>[90, 7, 219, 43, 210, 98, 77, 210, 189, 213, 9, 53, 23, 4, 138, 0, 51, 166, 21, 181]
                }, 
                :value=>[10000000000000000000, 0, 0, 0], 
                :input=>[16, 3, 226, 210, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2], 
                :access_list=>"None"
              }
            }
          }
        }, 
        []
      ]
    }
    encoded = Metadata.encode_call(call, metadata)
    expect(encoded).to eql("0x2c000120a1070000000000000000000000000000000000000000000000000000000000005a07db2bd2624dd2bdd5093517048a0033a615b50000e8890423c78a000000000000000000000000000000000000000000000000901003e2d2000000000000000000000000000000000000000000000000000000000000000200".to_bytes)
  end
end
