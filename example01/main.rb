require "scale_rb"

# WS connection

ScaleRb.logger.level = Logger::DEBUG

ScaleRb::WsClient.start('wss://polkadot-rpc.dwellir.com') do |client|
  puts client
  block_hash = client.chain_getBlockHash(21585684)
  puts block_hash
  runtime_version = client.state_getRuntimeVersion(block_hash)
  puts runtime_version[:specName]
  puts runtime_version[:specVersion]

  count = 0

  subscription_id = client.chain_subscribeNewHead do |head|
    count = count + 1

    if count < 5
      block_number = head[:number].to_i(16)
      block_hash = client.chain_getBlockHash(block_number)
      puts "Received new head at height: #{block_number}, block hash: #{block_hash}"
    else
      unsub_result = client.chain_unsubscribeNewHead(subscription_id)
      puts "Unsubscribed from new heads: #{unsub_result}"
    end
  end

  puts "Subscribed to new heads with subscription id: #{subscription_id}"

  block_number = 21711742
  block_hash = client.chain_getBlockHash(block_number)
  metadata = client.get_metadata(block_hash)

  puts "event count: #{client.get_storage('System', 'EventCount', block_hash:, metadata:)}"
  # event count: 48

  puts "treasury proposal #854: #{client.get_storage('Treasury', 'Proposals', [854], block_hash:, metadata:)}"
  # treasury proposal #854: {:proposer=>"0xb6f0f10eec993f3e6806eb6cc4d2f13d5f5a90a17b855a7bf9847a87e07ee322", :value=>82650000000000, :beneficiary=>"0xb6f0f10eec993f3e6806eb6cc4d2f13d5f5a90a17b855a7bf9847a87e07ee322", :bond=>0}

  puts "all treasury proposals: #{client.get_storage('Treasury', 'Proposals', block_hash:, metadata:)}"
  # all treasury proposals: [{:storage_key=>"0x89d139e01a5eb2256f222e5fc5dbe6b388c2f7188c6fdd1dffae2fa0d171f4400c1910093df9204856030000", :storage=>{:proposer=>"0xb6f0f10eec993f3e6806eb6cc4d2f13d5f5a90a17b855a7bf9847a87e07ee322", :value=>82650000000000, :beneficiary=>"0xb6f0f10eec993f3e6806eb6cc4d2f13d5f5a90a17b855a7bf9847a87e07ee322", :bond=>0}}, ...]

  puts "child bounties: #{client.get_storage('ChildBounties', 'ChildBounties', [11, 1646], block_hash:, metadata:)}"
  # child bounties: {:parent_bounty=>11, :value=>3791150000000, :fee=>0, :curator_deposit=>0, :status=>{:PendingPayout=>{:curator=>"0xb1725c0de514e0df808b19dbfca26672019ea5f9e2eb69c0055c7f1d01b4f18a", :beneficiary=>"0xb089dedc24a15308874dc862b035d74f2f7b45cad475d6121a2d944921bbe237", :unlock_at=>21703671}}}
end
