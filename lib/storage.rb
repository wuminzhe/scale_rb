# frozen_string_literal: true

module Storage
  class << self
    # params:
    #   pallet_name: module name
    #   method_name: storage name
    #   params:
    #     [
    #       [value, value_type_id, hasher],
    #       ...
    #     ]
    def encode_storage_key(pallet_name, method_name, params = [], registry = {})
      prefix = Hasher.twox128(pallet_name) + Hasher.twox128(method_name)
      params.reduce(prefix) do |memo, param|
        value, value_type_id, hasher = param
        memo + PortableTypes.encode_with_hasher(value, value_type_id, registry, hasher)
      end
    end
  end
end
