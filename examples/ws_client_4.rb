require 'scale_rb'

# ScaleRb.logger.level = Logger::DEBUG

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  client.chain_subscribeFinalizedHeads do |head|
    block_number = head['number'].to_i(16)
    block_hash = client.chain_getBlockHash(block_number)

    storage = client.get_storage(block_hash, 'System', 'Events')
    puts "block #{block_number}(#{block_hash}) has #{storage.length} events"
  end
end
