require 'scale_rb'

ScaleRb.logger.level = Logger::DEBUG

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')
block_number = 21711742
block_hash = client.chain_getBlockHash(block_number)
metadata = client.get_metadata(block_hash)

storage_query = ScaleRb::WsClient::StorageQuery.new(
  pallet_name: 'System',
  storage_name: 'Events',
)
storage = client.get_storage(block_hash, storage_query, metadata)
puts "block #{block_number}(#{block_hash}) has #{storage.length} events"
