# frozen_string_literal: true

require_relative 'decode'
require_relative 'encode'

module ScaleRb
  module Metadata
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
      def self.type_def?(type)
        return true if type.is_a?(Hash)
        return false unless type.is_a?(String)

        %w[bytes boolean string compact int uint option array vec tuple].any? do |t|
          send("#{t}?", type)
        end
      end

      def self.bytes?(type) = type.casecmp('bytes').zero?
      def self.boolean?(type) = %w[bool boolean].include?(type.downcase)
      def self.string?(type) = %w[str string text type].include?(type.downcase)
      def self.compact?(type) = type.casecmp('compact').zero? || type.match?(/\Acompact<.+>\z/i)
      def self.int?(type) = type.match?(/\Ai(8|16|32|64|128|256|512)\z/i)
      def self.uint?(type) = type.match?(/\Au(8|16|32|64|128|256|512)\z/i)
      def self.option?(type) = type.match?(/\Aoption<.+>\z/i)
      def self.array?(type) = type.match?(/\A\[.+\]\z/)
      def self.vec?(type) = type.match?(/\Avec<.+>\z/i)
      def self.tuple?(type) = type.match?(/\A\(.+\)\z/)
      def self.struct?(type) = type.is_a?(Hash)
      def self.enum?(type) = type.is_a?(Hash) && type.key?(:_enum)

      #########################################
      # type string parsing functions
      #########################################
      def self.parse_option(type) = type.[](/\Aoption<(.+)>\z/i, 1)

      def self.parse_array(type)
        type.match(/\A\[\s*(.+?)\s*;\s*(\d+)\s*\]\z/)&.yield_self do |m|
          [m[1], m[2].to_i]
        end || raise(ScaleRb::TypeParseError, type)
      end

      def self.parse_vec(type) = type.[](/\Avec<(.+)>\z/i, 1)
      def self.parse_tuple(type) = type[/\A\(\s*(.+)\s*\)\z/, 1].split(',').map(&:strip)

      #########################################
      # type registry functions
      #########################################
      def self._get_final_type_from_registry(registry, type)
        raise "Wrong lookup type #{type.class}" unless type.is_a?(String) || type.is_a?(Hash)
        return if type.is_a?(Hash)

        mapped = registry._get(type)
        return if mapped.nil?
        return mapped if type_def?(mapped)

        _get_final_type_from_registry(registry, mapped)
      end

      extend Decode
      extend Encode
    end
  end
end
