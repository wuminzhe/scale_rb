# frozen_string_literal: true

module Storage
  class << self
    # params:
    #   pallet_name: module name
    #   method_name: storage name
    #   params: {
    #     values: values,
    #     type_ids: type_ids,
    #     hashers: hashers,
    #     registry: portable_types_registry
    #   }
    def encode_storage_key(pallet_name, method_name, params = nil)
      pallet_method_key = Hasher.twox128(pallet_name) + Hasher.twox128(method_name)

      if params.nil?
        pallet_method_key
      else
        values = params[:values]
        type_ids = params[:type_ids]
        hashers = params[:hashers]
        registry = params[:registry]

        pallet_method_key + PortableTypes._encode_types_with_hashers(values, type_ids, registry, hashers)
      end
    end
  end
end
