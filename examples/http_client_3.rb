require 'scale_rb'

client = ScaleRb::HttpClient.new('https://polkadot-rpc.dwellir.com')
puts format('%20s: %s', 'supported_methods', client.supported_methods.join(', '))

block_number = 22_931_689
puts format('%20s: %d', 'block_number', block_number)

block_hash = client.chain_getBlockHash(block_number)
puts format('%20s: %s', 'block_hash', block_hash)

runtime_version = client.state_getRuntimeVersion(block_hash)
puts format('%20s: %s', 'spec_name', runtime_version[:specName])
puts format('%20s: %s', 'spec_version', runtime_version[:specVersion])

metadata = client.get_metadata(block_hash)

######################################
# Events
######################################
events = client.get_storage('System', 'Events', block_hash:, metadata:)
events.each_with_index do |event, index|
  puts format('%20s: %d', 'event index', index)
  puts format('%20s: %s', 'event', event)
end

######################################
# Validators
######################################
validators = client.get_storage('Session', 'Validators', block_hash:, metadata:)
validators.each_with_index do |validator, index|
  puts format('%20s: %d', 'validator index', index)
  puts format('%20s: %s', 'validator', ScaleRb::Utils.u8a_to_hex(validator))
end

######################################
# Block
######################################
blockResult = client.chain_getBlock(block_hash)

block = blockResult[:block]
justifications = blockResult[:justifications]
puts format('%20s: %s', 'justifications', justifications)

header = block[:header]

parent_hash = header[:parentHash]
puts format('%20s: %s', 'parent_hash', parent_hash)

state_root = header[:stateRoot]
puts format('%20s: %s', 'state_root', state_root)

extrinsics_root = header[:extrinsicsRoot]
puts format('%20s: %s', 'extrinsics_root', extrinsics_root)

digest_logs = header[:digest][:logs]
pre_runtime_log = nil
digest_logs.each_with_index do |digest_log, index|
  decoded, = ScaleRb::Codec.decode(
    metadata.digest_item_type_id,
    ScaleRb::Utils.hex_to_u8a(digest_log),
    metadata.registry
  )
  puts format('%20s: %d', 'log index', index)
  puts format('%20s: %s', 'log', decoded)

  # check if decoded has a key of "PreRuntime"
  pre_runtime_log = decoded[:PreRuntime] if decoded.key?(:PreRuntime)
end

engine = pre_runtime_log[0]
puts format('%20s: %s', 'engine', ScaleRb::Utils.u8a_to_utf8(engine))
data = pre_runtime_log[1] # if engine is BABE, data's type is sp_consensus_babe::digests::PreDigest
authority_index, = ScaleRb::CodecUtils.decode_uint('U32', data[1..]) # we don't need to decode the data, but get the authority_index
puts format('%20s: %d', 'authority_index', authority_index)
author = validators[authority_index]
puts format('%20s: %s', 'author', ScaleRb::Utils.u8a_to_hex(author))

extrinsics = block[:extrinsics]
extrinsics.each_with_index do |extrinsic, index|
  puts format('%20s: %d', 'extrinsic index', index)
  decoded = ScaleRb::ExtrinsicHelper.decode_extrinsic(ScaleRb::Utils.hex_to_u8a(extrinsic), metadata)
  puts format('%20s: %s', 'extrinsic', decoded)
end
