require 'scale_rb'

# You can have multiple subscriptions at the same time
ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  client.chain_subscribeNewHead do |head|
    puts "Received new head at height: #{head[:number].to_i(16)}"
  end

  client.state_subscribeStorage do |storage|
    block_hash = storage[:block]
    changes = storage[:changes]
    puts "Received #{changes.size} storage changes at block: #{block_hash}"
  end
end
