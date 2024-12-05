# frozen_string_literal: true

module ScaleRb
  module ExtrinsicHelper
    class << self
      def decode_extrinsic(bytes, metadata)
        extrinsic_hash = "0x#{Blake2b.hex(bytes, 32)}"

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
          call, = ScaleRb::Codec.decode(
            metadata.call_type_id, 
            remaining_bytes, 
            metadata.registry
          )
          {
            version: 4,
            signature: signature,
            call: call,
            extrinsic_hash: extrinsic_hash
          }
        else
          # puts "unsigned"
          {
            version: 4,
            call: ScaleRb::Codec.decode(
              metadata.call_type_id, 
              remaining_bytes, 
              metadata.registry
            ),
            extrinsic_hash: extrinsic_hash
          }
        end
      end
    end
  end
end
