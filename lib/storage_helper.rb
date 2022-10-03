# frozen_string_literal: true

module StorageHelper
  class << self
    # params:
    #   pallet_name: module name
    #   method_name: storage name
    #   params: {
    #     values: values,
    #     type_ids: type_ids,
    #     hashers: hashers,
    #   }
    #   registry: portable_types_registry
    def encode_storage_key(pallet_name, method_name, params = nil, registry = nil)
      pallet_method_key = Hasher.twox128(pallet_name) + Hasher.twox128(method_name)

      if params.nil?
        pallet_method_key
      else
        values = params[:values]
        type_ids = params[:type_ids]
        hashers = params[:hashers]

        pallet_method_key + PortableCodec._encode_types_with_hashers(values, type_ids, registry, hashers)
      end
    end

    def build_params(param_values, storage_key_type_id, hashers, registry)
      type_ids = registry._get(storage_key_type_id)._get(:def)._get(:tuple)
      type_ids = [storage_key_type_id] if type_ids.nil?
      {
        values: param_values,
        type_ids: type_ids,
        hashers: hashers
      }
    end
  end
end
