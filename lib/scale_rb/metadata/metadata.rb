# frozen_string_literal: true

require_relative './metadata_v9'
require_relative './metadata_v10'
require_relative './metadata_v11'
require_relative './metadata_v12'
require_relative './metadata_v13'
require_relative './metadata_v14'

# NOTE: Only v14 and later are supported.
# https://github.com/paritytech/frame-metadata/blob/main/frame-metadata/src/lib.rs#L85
module ScaleRb
  module Metadata
    class Metadata
      attr_reader :magic_number, :version, :metadata, :registry

      def initialize(metadata_prefixed, types = nil)
        @metadata_prefixed = metadata_prefixed
        @magic_number = @metadata_prefixed[:magicNumber]
        metadata = @metadata_prefixed[:metadata]
        @version = metadata.keys.first
        raise "Unsupported metadata version: #{@version}" unless [:V14, :V13, :V12, :V11, :V10, :V9].include?(@version)

        @metadata = metadata[@version]
        if @version == :V14
          @registry = ScaleRb::PortableRegistry.new(@metadata.dig(:lookup, :types))
        else
          @registry = ScaleRb::OldRegistry.new(types)
        end
      end

      def self.from_hex(hex)
        metadata_prefixed, = ScaleRb::Codec.decode('MetadataPrefixed', Utils.hex_to_u8a(hex), OldRegistry.new(TYPES))
        Metadata.new(metadata_prefixed)
      end

      def self.from_json(str)
        metadata_prefixed = JSON.parse(str, symbolize_names: true)
        Metadata.new(metadata_prefixed)
      end

      def to_json(*_args)
        JSON.pretty_generate(@metadata_prefixed)
      end

      def pallet(pallet_name)
        @metadata[:pallets].find do |pallet|
          pallet[:name] == pallet_name
        end
      end

      def pallet_by_index(pallet_index)
        @metadata[:pallets].find do |pallet|
          pallet[:index] == pallet_index
        end
      end

      def storage(pallet_name, item_name)
        pallet = pallet(pallet_name)
        raise "Pallet `#{pallet_name}` not found" if pallet.nil?

        pallet.dig(:storage, :items).find do |item|
          item[:name] == item_name
        end
      end

      def calls_type_id(pallet_name)
        pallet = pallet(pallet_name)
        raise "Pallet `#{pallet_name}` not found" if pallet.nil?

        pallet.dig(:calls, :type)
      end

      def call(pallet_name, call_name)
        calls_type_id = calls_type_id(pallet_name)
        calls_type = @types[calls_type_id]
        raise 'Calls type is not correct' if calls_type.nil?

        calls_type.dig(:type, :def, :variant, :variants).find do |variant|
          variant[:name].downcase == call_name.downcase
        end
      end
    end

    TYPES = {
      'Type' => 'Str',
      'Bytes' => 'Vec<u8>',
      'MetadataPrefixed' => {
        'magicNumber' => 'U32',
        'metadata' => 'Metadata'
      },
      'Placeholder' => 'Null',
      'Metadata' => {
        '_enum' => {
          'V0' => 'Placeholder',
          'V1' => 'Placeholder',
          'V2' => 'Placeholder',
          'V3' => 'Placeholder',
          'V4' => 'Placeholder',
          'V5' => 'Placeholder',
          'V6' => 'Placeholder',
          'V7' => 'Placeholder',
          'V8' => 'Placeholder',
          'V9' => 'MetadataV9',
          'V10' => 'MetadataV10',
          'V11' => 'MetadataV11',
          'V12' => 'MetadataV12',
          'V13' => 'MetadataV13',
          'V14' => 'MetadataV14'
        }
      }
    }.merge(MetadataV14::TYPES)
            .merge(MetadataV13::TYPES)
            .merge(MetadataV12::TYPES)
            .merge(MetadataV11::TYPES)
            .merge(MetadataV10::TYPES)
            .merge(MetadataV9::TYPES)
  end
end
