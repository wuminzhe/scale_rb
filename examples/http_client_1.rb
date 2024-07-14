
require 'scale_rb'

ScaleRb.logger.level = Logger::DEBUG

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')
block_hash = client.chain_getBlockHash(21585684)
runtime_version = client.state_getRuntimeVersion(block_hash)
puts runtime_version
