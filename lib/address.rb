require 'base58'

# Warning: Just for test
class Address
  SS58_PREFIX = 'SS58PRE'

  TYPES = [
    # Polkadot Live (SS58, AccountId)
    0, 1,
    # Polkadot Canary (SS58, AccountId)
    2, 3,
    # Kulupu (SS58, Reserved)
    16, 17,
    # Darwinia Live
    18,
    # Dothereum (SS58, AccountId)
    20, 21, 
    # Generic Substrate wildcard (SS58, AccountId)
    42, 43,

    # Schnorr/Ristretto 25519 ("S/R 25519") key
    48,
    # Edwards Ed25519 key
    49,
    # ECDSA SECP256k1 key
    50,

    # Reserved for future address format extensions.
    *64..255
  ]

  class << self

    def array_to_hex_string(arr)
      body = arr.map { |i| i.to_s(16).rjust(2, '0') }.join
      "0x#{body}"
    end

    def decode(address, addr_type = 42, ignore_checksum = true)
      decoded = Base58.base58_to_binary(address, :bitcoin)
      is_pubkey = decoded.size == 35

      size = decoded.size - ( is_pubkey ? 2 : 1 )

      prefix = decoded[0, 1].unpack("C*").first

      raise "Invalid address type" unless TYPES.include?(addr_type)
      
      hash_bytes = make_hash(decoded[0, size])
      if is_pubkey
        is_valid_checksum = decoded[-2].unpack("C*").first == hash_bytes[0] && decoded[-1].unpack("C*").first == hash_bytes[1]
      else
        is_valid_checksum = decoded[-1].unpack("C*").first == hash_bytes[0]
      end

      # raise "Invalid decoded address checksum" unless is_valid_checksum && ignore_checksum

      decoded[1...size].unpack("H*").first
    end


    def encode(pubkey, addr_type = 42)
      pubkey = pubkey[2..-1] if pubkey =~ /^0x/i
      key = [pubkey].pack("H*")

      u8_array = key.bytes

      u8_array.unshift(addr_type)

      bytes = make_hash(u8_array.pack("C*"))
      
      checksum = bytes[0, key.size == 32 ? 2 : 1]

      u8_array.push(*checksum)

      u8_array = u8_array.map { |i| if i.is_a?(String) then i.to_i(16) else i end }
      # u8_array = [42, 202, 122, 179, 154, 86, 153, 242, 157, 207, 38, 115, 170, 163, 73, 75, 72, 81, 26, 186, 224, 220, 60, 101, 15, 243, 152, 246, 95, 229, 225, 18, 56, 0x7e]
      input = u8_array.pack("C*")

      Base58.binary_to_base58(input, :bitcoin)
    end

    def make_hash(body)
      Blake2b.hex("#{SS58_PREFIX}#{body}".bytes, 64)
    end

    def is_ss58_address?(address)
      begin
        decode(address)
      rescue
        return false
      end
      return true
    end

  end
end