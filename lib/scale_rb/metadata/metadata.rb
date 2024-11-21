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

      # Runtime type ids
      attr_reader :unchecked_extrinsic_type_id, :address_type_id, :call_type_id, :extrinsic_signature_type_id
      attr_reader :digest_type_id, :digest_item_type_id, :event_record_list_type_id, :event_record_type_id, :event_type_id
      attr_reader :signature_type_id

      def initialize(metadata_prefixed, unchecked_extrinsic_type_id = nil)
        @metadata_prefixed = metadata_prefixed
        @magic_number = @metadata_prefixed[:magicNumber]
        metadata = @metadata_prefixed[:metadata]
        @version = metadata.keys.first
        raise "Unsupported metadata version: #{@version}" unless :V14 == @version

        @metadata = metadata[@version]
        @registry = ScaleRb::PortableRegistry.new(@metadata.dig(:lookup, :types))

        @unchecked_extrinsic_type_id = unchecked_extrinsic_type_id || find_unchecked_extrinsic_type_id
        @address_type_id = find_address_type_id
        @call_type_id = find_call_type_id
        @extrinsic_signature_type_id = find_extrinsic_signature_type_id

        @digest_type_id = find_digest_type_id
        @digest_item_type_id = find_digest_item_type_id

        @event_record_list_type_id = find_event_record_list_type_id
        @event_record_type_id = find_event_record_type_id
        @event_type_id = find_event_type_id

        @signature_type_id = build_signature_type_id
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

      #########################################################################

      def calls_type_id(pallet_name)
        pallet = pallet(pallet_name)
        raise "Pallet `#{pallet_name}` not found" if pallet.nil?

        pallet.dig(:calls, :type)
      end

      # % call_type :: String -> String -> ScaleRb::Types::StructType
      def call_type(pallet_name, call_name)
        calls_type_id = calls_type_id(pallet_name)

        calls_type = @registry[calls_type_id] # #<ScaleRb::Types::VariantType ...>
        raise 'Calls type is not correct' if calls_type.nil?

        v = calls_type.variants.find do |variant|
          variant.name.to_s.downcase == call_name.downcase
        end

        raise "Call `#{call_name}` not found" if v.nil?

        v.struct
      end

      private

      def find_unchecked_extrinsic_type_id
        @registry.types.each_with_index do |type, index|
          if type.path.first == 'sp_runtime' && type.path.last == 'UncheckedExtrinsic'
            return index
          end
        end
      end

      def find_address_type_id
        @registry[@unchecked_extrinsic_type_id].params.find do |param|
          param.name.downcase == 'address'
        end.type
      end

      def find_call_type_id
        @registry[@unchecked_extrinsic_type_id].params.find do |param|
          param.name.downcase == 'call'
        end.type
      end

      def find_extrinsic_signature_type_id
        @registry[@unchecked_extrinsic_type_id].params.find do |param|
          param.name.downcase == 'signature'
        end.type
      end

      def find_digest_type_id
        storage_item = storage('System', 'Digest')
        storage_item.dig(:type, :plain)
      end

      def find_digest_item_type_id
        # #<ScaleRb::Types::StructType registry=a_portable_registry path=["sp_runtime", "generic", "digest", "Digest"] params=[] fields=[#<ScaleRb::Types::Field name="logs" type=14>]>
        digest_type = @registry[@digest_type_id]

        field = digest_type.fields.find do |field|
          field.name == 'logs'
        end
        seq = @registry[field.type]
        raise 'Type is not correct' unless seq.is_a?(ScaleRb::Types::SequenceType)

        seq.type
      end

      def find_event_record_list_type_id
        storage_item = storage('System', 'Events')
        storage_item.dig(:type, :plain)
      end

      def find_event_record_type_id
        seq = @registry[@event_record_list_type_id]
        raise 'Type is not correct' unless seq.is_a?(ScaleRb::Types::SequenceType)

        seq.type
      end

      def find_event_type_id
        @registry[@event_record_type_id].fields.find do |field|
          field.name == 'event'
        end.type
      end

      def build_signature_type_id
        signed_extensions_type = ScaleRb::Types::StructType.new(
          path: ['SignedExtensions'],
          fields: @metadata[:extrinsic][:signedExtensions].map do |signed_extension|
            ScaleRb::Types::Field.new(
              name: signed_extension[:identifier],
              type: signed_extension[:type]
            )
          end
        )

        signed_extensions_type_id = @registry.add_type(signed_extensions_type)

        signature_type = ScaleRb::Types::StructType.new(
          path: ['ExtrinsicSignature'],
          fields: [
            ScaleRb::Types::Field.new(name: 'address', type: @address_type_id),
            ScaleRb::Types::Field.new(name: 'signature', type: @extrinsic_signature_type_id),
            ScaleRb::Types::Field.new(name: 'signedExtensions', type: signed_extensions_type_id)
          ]
        )

        @registry.add_type(signature_type)
      end
    end

    #########################################################################

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
