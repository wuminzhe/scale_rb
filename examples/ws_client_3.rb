require 'scale_rb'
require 'async'

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  client.chain_subscribeNewHead do |head|
    block_number = head['number'].to_i(16)
    block_hash = client.chain_getBlockHash(block_number)
    puts "Received new head at height: #{block_number}, block hash: #{block_hash}"
  end
end