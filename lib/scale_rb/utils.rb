# frozen_string_literal: true

class Hash
  # Check if the key exists in the hash
  # @param key [String | Symbol] Key to check
  # @return [Boolean] True if the key exists, false otherwise
  def _key?(key)
    ScaleRb::Utils.key?(self, key)
  end

  # Get the value from the hash
  # @param keys [Array<String | Symbol>] Keys to get the value from
  # @return [Object | NilClass] Value if the key exists, nil otherwise
  def _get(*keys)
    ScaleRb::Utils.get(self, *keys)
  end
end

module ScaleRb
  module Utils
    class << self
      # https://www.rubyguides.com/2017/01/read-binary-data/
      def hex_to_u8a(str)
        data = str.start_with?('0x') ? str[2..] : str
        raise 'Not valid hex string' if data =~ /[^\da-f]+/i

        data = "0#{data}" if data.length.odd?
        data.scan(/../).map(&:hex)
      end

      def camelize(str)
        str.split('_').collect(&:capitalize).join
      end

      def underscore(str)
        str.gsub(/::/, '/')
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .tr('-', '_')
           .downcase
      end

      def int_to_u8a(int, bit_length = nil)
        hex = bit_length ? int.to_s(16).rjust(bit_length / 4, '0') : int.to_s(16)
        hex_to_u8a(hex)
      end

      def uint_to_int(unsigned, bit_length)
        unsigned_mid = 2**(bit_length - 1)
        unsigned_ceiling = 2**bit_length
        unsigned >= unsigned_mid ? unsigned - unsigned_ceiling : unsigned
      end

      def int_to_uint(signed, bit_length)
        unsigned_mid = 2**(bit_length - 1)
        unsigned_ceiling = 2**bit_length
        raise 'Out of scope' if signed >= unsigned_mid || signed <= -unsigned_mid

        signed.negative? ? unsigned_ceiling + signed : signed
      end

      # unix timestamp to utc
      def unix_to_utc(unix)
        Time.at(unix).utc.asctime
      end

      # utc to unix timestamp
      def utc_to_unix(utc_asctime)
        Time.parse(utc_asctime)
      end

      def u8a?(arr)
        arr.all? { |e| e >= 0 && e <= 255 }
      end

      def u8a_to_hex(u8a)
        raise 'Not a byte array' unless u8a?(u8a)

        u8a.reduce('0x') { |hex, u8| hex + u8.to_s(16).rjust(2, '0') }
      end

      def u8a_to_bin(u8a)
        raise 'Not a byte array' unless u8a?(u8a)

        u8a.reduce('0b') { |bin, u8| bin + u8.to_s(2).rjust(8, '0') }
      end

      def u8a_to_utf8(u8a)
        raise 'Not a byte array' unless u8a?(u8a)

        u8a.pack('C*').force_encoding('utf-8')
      end

      def u8a_to_uint(u8a)
        u8a_to_hex(u8a).to_i(16)
      end

      def u8a_to_int(u8a, bit_length)
        uint_to_int(u8a_to_uint(u8a), bit_length)
      end

      def key?(hash, key)
        if key.instance_of?(String)
          hash.key?(key) || hash.key?(key.to_sym)
        else
          hash.key?(key) || hash.key?(key.to_s)
        end
      end

      def get(hash, *keys)
        keys.reduce(hash) do |h, key|
          break nil unless h.is_a?(Hash)

          if key.instance_of?(String)
            h[key] || h[key.to_sym]
          elsif key.instance_of?(Symbol)
            h[key] || h[key.to_s]
          else
            h[key]
          end
        end
      end
    end
  end
end
