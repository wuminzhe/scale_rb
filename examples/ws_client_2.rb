require 'scale_rb'

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  client.chain_subscribeNewHead do |head|
    puts "Received new head at height: #{head['number'].to_i(16)}"
  end
end