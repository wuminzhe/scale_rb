require 'scale_rb'

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  client.chain_subscribeFinalizedHeads do |head|
    block_number = head['number'].to_i(16)
    block_hash = client.chain_getBlockHash(block_number)

    result = client.get_storage(block_hash, 'System', 'Events')
    puts "block #{block_number}(#{block_hash}) has #{result.length} events"
  end

  # client.state_subscribeStorage(['0x26aa394eea5630e07c48ae0c9558cef780d41e5e16056765bc8461851072c9d7']) do |storage|
  #   block_hash = storage['block']
  #   changes = storage['changes']
  #   events_hex = changes[0][1]
  #
  #   block = client.chain_getBlock(block_hash)
  #
  #   metadata = ScaleRb::MetadataHelper.get_metadata_by_block_hash(client, '../metadata', block_hash)
  #   result = ScaleRb::StorageHelper.decode_storage3(events_hex, 'System', 'Events', metadata)
  #
  #   block_number = block['block']['header']['number'].to_i(16)
  #   puts "block #{block_number}(#{block_hash}) has #{result.length} events"
  # end
end
