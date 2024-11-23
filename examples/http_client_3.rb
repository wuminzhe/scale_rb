require 'scale_rb'

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')

block_number = 22931689
puts sprintf('%20s: %d', "block_number", block_number)

block_hash = client.chain_getBlockHash(block_number)
metadata = client.get_metadata(block_hash)
# puts client.supported_methods

blockResult = client.chain_getBlock(block_hash)

block = blockResult[:block]
justifications = blockResult[:justifications]

header = block[:header]

parent_hash = header[:parentHash]
puts sprintf('%20s: %s', "parent_hash", parent_hash)

state_root = header[:stateRoot]
puts sprintf('%20s: %s', "state_root", state_root)

extrinsics_root = header[:extrinsicsRoot]
puts sprintf('%20s: %s', "extrinsics_root", extrinsics_root)

digest_logs = header[:digest][:logs]
digest_logs.each_with_index do |digest_log, index|
  decoded, _ = ScaleRb::Codec.decode(
    metadata.digest_item_type_id, 
    ScaleRb::Utils.hex_to_u8a(digest_log), 
    metadata.registry
  )
  puts sprintf('%20s: %d', "log index", index)
  puts sprintf('%20s: %s', "log", decoded)
end

def decode_extrinsic(bytes, metadata)
  _, remaining_bytes = ScaleRb::Codec.decode_compact(bytes)
  meta, remaining_bytes = [remaining_bytes[0], remaining_bytes[1..]]
  signed = (meta & 0x80) == 0x80
  version = (meta & 0x7f)

  raise "Unsupported version: #{version}" unless version == 4

  if signed
    # puts "signed"
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
    # puts "unsigned"
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
  puts sprintf('%20s: %d', "extrinsic index", index)
  decoded = decode_extrinsic(ScaleRb::Utils.hex_to_u8a(extrinsic), metadata)
  puts sprintf('%20s: %s', "extrinsic", decoded)
end
