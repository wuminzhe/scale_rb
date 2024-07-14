
require 'scale_rb'

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')
block_number = 21585684
block_hash = client.chain_getBlockHash(block_number)
storage = client.get_storage(block_hash, 'System', 'Events')
puts "block #{block_number}(#{block_hash}) has #{storage.length} events"
