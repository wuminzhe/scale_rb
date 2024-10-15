# frozen_string_literal: true

module ScaleRb
  module ExtrinsicHelper
    def decode_extrinsic(bytes, metadata_prefixed)
      meta = bytes[0]
      signed = (meta & 0x80) == 0x80
      version = (meta & 0x7f)

      raise "Unsupported version: #{version}" unless version == 4

      nil unless signed
    end

    def patch_types(registry, metadata_prefixed)
      add_signed_extensions_type(metadata_prefixed.signed_extensions, registry)
    end

    private

    def add_signed_extensions_type(signed_extensions, registry)
      type = Types::StructType.new(
        fields: signed_extensions.map do |signed_extension|
          Types::Field.new(
            name: Utils.camelize(signed_extension._get(:identifier)),
            type: signed_extension._get(:type)
          )
        end,
        registry:
      )
      registry.add_type(type)
    end
  end
end
