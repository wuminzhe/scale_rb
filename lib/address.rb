require 'base58'

# Warning: Just for test
module ScaleRb
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

      def decode(address, addr_type = 42, _ignore_checksum = true)
        decoded = Base58.base58_to_binary(address, :bitcoin)
        is_pubkey = decoded.size == 35

        size = decoded.size - (is_pubkey ? 2 : 1)

        prefix = decoded[0, 1].unpack1('C*')

        raise 'Invalid address type' unless TYPES.include?(addr_type)

        hash_bytes = make_hash(decoded[0, size])
        is_valid_checksum =
          if is_pubkey
            decoded[-2].unpack1('C*') == hash_bytes[0] && decoded[-1].unpack1('C*') == hash_bytes[1]
          else
            decoded[-1].unpack1('C*') == hash_bytes[0]
          end

        # raise "Invalid decoded address checksum" unless is_valid_checksum && ignore_checksum

        decoded[1...size].unpack1('H*')
      end

      def encode(pubkey, addr_type = 42)
        pubkey = pubkey[2..-1] if pubkey =~ /^0x/i
        key = [pubkey].pack('H*')

        pubkey_bytes = key.bytes

        checksum_length = case pubkey_bytes.length
                          when 32, 33
                            2
                          when 1, 2, 4, 8
                            1
                          else
                            raise 'Invalid pubkey length'
                          end

        ss58_format_bytes = if addr_type < 64
                              [addr_type].pack('C*')
                            else
                              [
                                ((ss58_format & 0b0000_0000_1111_1100) >> 2) | 0b0100_0000,
                                (ss58_format >> 8) | ((ss58_format & 0b0000_0000_0000_0011) << 6)
                              ].pack('C*')
                            end

        input_bytes = ss58_format_bytes.bytes + pubkey_bytes
        checksum = Blake2b.hex(SS58_PREFIX.bytes + input_bytes, 64).to_bytes

        Base58.binary_to_base58((input_bytes + checksum[0...checksum_length]).pack('C*'), :bitcoin)
      end

      def make_hash(body)
        Blake2b.hex("#{SS58_PREFIX}#{body}".bytes, 64)
      end

      def is_ss58_address?(address)
        begin
          decode(address)
        rescue StandardError
          return false
        end
        true
      end
    end
  end
end
