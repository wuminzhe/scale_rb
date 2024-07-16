require 'scale_rb'

# ScaleRb.logger.level = Logger::DEBUG

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  count = 0

  subscription_id = client.chain_subscribeNewHead do |head|
    count = count + 1

    if count < 5
      block_number = head['number'].to_i(16)
      block_hash = client.chain_getBlockHash(block_number)
      puts "Received new head at height: #{block_number}, block hash: #{block_hash}"
    else
      unsub_result = client.chain_unsubscribeNewHead(subscription_id)
      puts "Unsubscribed from new heads: #{unsub_result}"
    end
  end

  puts "Subscribed to new heads with subscription id: #{subscription_id}"
end
