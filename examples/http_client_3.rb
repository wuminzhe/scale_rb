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
  puts "decoded log: #{decoded}"
end

def decode_extrinsic(bytes, metadata)
  _, remaining_bytes = ScaleRb::Codec.decode_compact(bytes)
  meta, remaining_bytes = [remaining_bytes[0], remaining_bytes[1..]]
  signed = (meta & 0x80) == 0x80
  version = (meta & 0x7f)

  raise "Unsupported version: #{version}" unless version == 4

  if signed
    puts "signed"
    signature, remaining_bytes = ScaleRb::Codec.decode(
      metadata.signature_type_id, 
      remaining_bytes, 
      metadata.registry
    )
    call, remaining_bytes = ScaleRb::Codec.decode(
      metadata.call_type_id, 
      remaining_bytes, 
      metadata.registry
    )
    {
      version: 4,
      signature: signature,
      call: call
    }
  else
    puts "unsigned"
    {
      version: 4,
      call: ScaleRb::Codec.decode(
        metadata.call_type_id, 
        remaining_bytes, 
        metadata.registry
      )
    }
  end
end

extrinsics = block[:extrinsics]
extrinsics.each_with_index do |extrinsic, index|
  puts "extrinsic index: #{index}"
  puts "extrinsic hex: #{extrinsic}"
  decoded = decode_extrinsic(ScaleRb::Utils.hex_to_u8a(extrinsic), metadata)
  puts "extrinsic decoded: #{decoded}"
end
