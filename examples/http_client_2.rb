require 'scale_rb'

def fetch_some_storages(client, block_number)
  start_time = Time.now

  block_hash = client.chain_getBlockHash(block_number)
  metadata = client.get_metadata(block_hash)
  puts "event count: #{client.get_storage('System', 'EventCount', block_hash:, metadata:)}"
  puts "treasury proposal #854: #{client.get_storage('Treasury', 'Proposals', [854], block_hash:, metadata:)}"
  puts "all treasury proposals: #{client.get_storage('Treasury', 'Proposals', block_hash:, metadata:)}"
  puts "child bounties: #{client.get_storage('ChildBounties', 'ChildBounties', [11, 1646], block_hash:, metadata:)}"

  end_time = Time.now
  puts "Time taken: #{end_time - start_time} seconds"
end

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')
fetch_some_storages(client, 21711742)
