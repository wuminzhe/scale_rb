# frozen_string_literal: true

module ScaleRb
  module OldRegistry
    module Codec
      class Error < StandardError; end
      class NotImplemented < Error; end
      class NilTypeError < Error; end
      class TypeParseError < Error; end
      class NotEnoughBytesError < Error; end
      class InvalidBytesError < Error; end
      class Unreachable < Error; end
      class IndexOutOfRangeError < Error; end
      class LengthNotEqualErr < Error; end
      class InvalidValueError < Error; end

      #########################################
      # type definition check functions
      #########################################
      def type_def?(type)
        return true if type.is_a?(Hash)
        return false unless type.is_a?(String)

        %w[bytes boolean string compact int uint option array vec tuple].any? do |t|
          send("#{t}?", type)
        end
      end

      def bytes?(type) = type.casecmp('bytes').zero?
      def boolean?(type) = %w[bool boolean].include?(type.downcase)
      def string?(type) = %w[str string text type].include?(type.downcase)
      def compact?(type) = type.casecmp('compact').zero? || type.match?(/\Acompact<.+>\z/i)
      def int?(type) = type.match?(/\Ai(8|16|32|64|128|256|512)\z/i)
      def uint?(type) = type.match?(/\Au(8|16|32|64|128|256|512)\z/i)
      def option?(type) = type.match?(/\Aoption<.+>\z/i)
      def array?(type) = type.match?(/\A\[.+\]\z/)
      def vec?(type) = type.match?(/\Avec<.+>\z/i)
      def tuple?(type) = type.match?(/\A\(.+\)\z/)
      def struct?(type) = type.is_a?(Hash)
      def enum?(type) = type.is_a?(Hash) && type.key?(:_enum)

      #########################################
      # type string parsing functions
      #########################################
      def parse_option(type) = type.[](/\Aoption<(.+)>\z/i, 1)

      def parse_array(type)
        type.match(/\A\[\s*(.+?)\s*;\s*(\d+)\s*\]\z/)&.yield_self do |m|
          [m[1], m[2].to_i]
        end || raise(ScaleRb::TypeParseError, type)
      end

      def parse_vec(type) = type.[](/\Avec<(.+)>\z/i, 1)
      def parse_tuple(type) = type[/\A\(\s*(.+)\s*\)\z/, 1].split(',').map(&:strip)

      #########################################
      # type registry functions
      #########################################
      def _get_final_type_from_registry(registry, type)
        raise "Wrong lookup type #{type.class}" unless type.is_a?(String) || type.is_a?(Hash)
        return if type.is_a?(Hash)

        mapped = registry._get(type)
        return if mapped.nil?
        return mapped if type_def?(mapped)

        _get_final_type_from_registry(registry, mapped)
      end
    end
  end
end

# Helper functions
# TODO: set, bitvec
module ScaleRb
  class << self
  end
end

module ScaleRb
  # Decode
  class << self
  end

  # Encode
  class << self
  end
end
