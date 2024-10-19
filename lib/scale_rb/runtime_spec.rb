# frozen_string_literal: true

require_relative './metadata/metadata'

module ScaleRb
  class RuntimeSpec
    attr_reader :metadata, :version

    def initialize(hex)
      @metadata_prefixed, = ScaleRb::Codec.decode(
        'MetadataPrefixed',
        ScaleRb::Utils.hex_to_u8a(hex),
        ScaleRb::OldRegistry.new(Metadata::TYPES)
      )
      metadata = @metadata_prefixed[:metadata]
      @version = metadata.keys.first
      @metadata = metadata[@version]
    end

    def portable_registry
      @portable_registry ||=
        case @version
        when :V14
          ScaleRb::PortableRegistry.new(@metadata.dig(:lookup, :types))
        else
          raise NotImplementedError, @version
        end
    end

    def pallet(pallet_name)
      @metadata._get(:pallets).find do |p|
        p._get(:name) == pallet_name
      end
    end
  end
end
