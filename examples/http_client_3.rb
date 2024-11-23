require 'scale_rb'

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')

block_number = 22931689
puts sprintf('%20s: %d', "block_number", block_number)

block_hash = client.chain_getBlockHash(block_number)
puts sprintf('%20s: %s', "block_hash", block_hash)

metadata = client.get_metadata(block_hash)
# puts client.supported_methods

events = client.get_storage('System', 'Events', block_hash:, metadata:)

events.each_with_index do |event, index|
  puts sprintf('%20s: %d', "event index", index)
  puts sprintf('%20s: %s', "event", event)
end

# blockResult = client.chain_getBlock(block_hash)

# block = blockResult[:block]
# justifications = blockResult[:justifications]

# header = block[:header]

# parent_hash = header[:parentHash]
# puts sprintf('%20s: %s', "parent_hash", parent_hash)

# state_root = header[:stateRoot]
# puts sprintf('%20s: %s', "state_root", state_root)

# extrinsics_root = header[:extrinsicsRoot]
# puts sprintf('%20s: %s', "extrinsics_root", extrinsics_root)

# digest_logs = header[:digest][:logs]
# digest_logs.each_with_index do |digest_log, index|
#   decoded, _ = ScaleRb::Codec.decode(
#     metadata.digest_item_type_id, 
#     ScaleRb::Utils.hex_to_u8a(digest_log), 
#     metadata.registry
#   )
#   puts sprintf('%20s: %d', "log index", index)
#   puts sprintf('%20s: %s', "log", decoded)
# end

# extrinsics = block[:extrinsics]
# extrinsics.each_with_index do |extrinsic, index|
#   puts sprintf('%20s: %d', "extrinsic index", index)
#   decoded = ScaleRb::ExtrinsicHelper.decode_extrinsic(ScaleRb::Utils.hex_to_u8a(extrinsic), metadata)
#   puts sprintf('%20s: %s', "extrinsic", decoded)
# end
