require 'scale_rb'

# ScaleRb.logger.level = Logger::DEBUG

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  block_hash = client.chain_getBlockHash(21585684)
  runtime_version = client.state_getRuntimeVersion(block_hash)
  puts runtime_version['specName']
  puts runtime_version['specVersion']
end
