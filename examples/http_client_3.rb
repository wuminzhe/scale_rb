require 'scale_rb'

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')
block_hash = client.chain_getBlockHash(22931689)
metadata = client.get_metadata(block_hash)
# puts client.supported_methods

blockResult = client.chain_getBlock(block_hash)

block = blockResult[:block]
justifications = blockResult[:justifications]

header = block[:header]

parent_hash = header[:parentHash]
puts "parent_hash: #{parent_hash}"

state_root = header[:stateRoot]
puts "state_root: #{state_root}"

extrinsics_root = header[:extrinsicsRoot]
puts "extrinsics_root: #{extrinsics_root}"

digest_logs = header[:digest][:logs]
digest_logs.each do |digest_log|
  puts "digest_log: #{digest_log}"
  decoded, _ = ScaleRb::Codec.decode(
    metadata.digest_item_type_id, 
    ScaleRb::Utils.hex_to_u8a(digest_log), 
    metadata.registry
  )
  p decoded
end

# extrinsics = block[:extrinsics]
# puts "Extrinsics count: #{extrinsics.size}"
