require 'scale_rb'

# Unsubscribe after receiving 4 new heads
ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  count = 0

  subscription_id = client.chain_subscribeNewHead do |head|
    count += 1

    if count < 5
      block_number = head[:number].to_i(16)
      block_hash = client.chain_getBlockHash(block_number)
      puts "Received new head at height: #{block_number}, block hash: #{block_hash}"
    else
      unsub_result = client.chain_unsubscribeNewHead(subscription_id)
      puts "Unsubscribe #{subscription_id} #{unsub_result === true ? 'succeeded' : 'failed'}"
    end
  end

  puts "Subscribed to new heads with subscription id: #{subscription_id}"
end
