# frozen_string_literal: true

require_relative './metadata/metadata'

module ScaleRb
  class RuntimeTypes
    attr_reader :metadata, :version

    def initialize(hex, types = nil)
      @metadata_prefixed, = ScaleRb::Codec.decode(
        'MetadataPrefixed',
        ScaleRb::Utils.hex_to_u8a(hex),
        ScaleRb::OldRegistry.new(Metadata::TYPES)
      )
      metadata = @metadata_prefixed[:metadata]
      @version = metadata.keys.first
      @metadata = metadata[@version]
      raise "Unsupported metadata version: #{@version}" unless @version == :V14
    end

    def registry
      @registry ||=
        ScaleRb::PortableRegistry.new(@metadata.dig(:lookup, :types))
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

    # example:
    # #<ScaleRb::Types::StructVariant name=:remark index=1 struct=#<ScaleRb::Types::StructType registry=a_portable_registry path=nil fields=[#<ScaleRb::Types::Field name="remark" type=12>]>>
    def call(pallet_name, call_name)
      calls_type = registry[calls_type_id(pallet_name)]
      raise 'Calls type is not correct' unless calls_type.is_a?(ScaleRb::Types::VariantType)

      calls_type.variants.find do |variant|
        variant.name == call_name.to_sym
      end
    end

    private

    def calls_type_id(pallet_name)
      pallet = pallet(pallet_name)
      raise "Pallet `#{pallet_name}` not found" if pallet.nil?

      pallet.dig(:calls, :type)
    end
  end
end
