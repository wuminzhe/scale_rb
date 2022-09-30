# frozen_string_literal: true

module Client
  class << self
    def get_metadata(url, at = nil)
      hex = RPC.state_getMetadata(url, at)
      ScaleRb2.decode_metadata(hex.strip.to_bytes)
    end
  end
end
