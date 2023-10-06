# frozen_string_literal: true

require 'json'

module ScaleRb
  module RpcRequestBuilder
    def build_json_rpc_body(method, params, id)
      {
        'id' => id,
        'jsonrpc' => '2.0',
        'method' => method,
        'params' => params.reject(&:nil?)
      }.to_json
    end

    def respond_to_missing?(*_args)
      true
    end

    # example:
    #   state_getStorage(1, '0x363a..', 563_868)
    #
    #   ==
    #
    #   build_json_rpc_body('state_getStorage', ['0x363a..', 563_868], 1)
    def method_missing(method, *args)
      build_json_rpc_body(method, args[1..], args[0])
    end

    ###################################
    # derived functions
    ###################################
    def derived_state_get_storage(rpc_id, pallet_name, item_name, key = nil, registry = nil)
      storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry)._to_hex
      state_getStorage(rpc_id, [storage_key])
    end

    def derived_state_subscribe_storage(rpc_id, pallet_name, item_name, key = nil, registry = nil)
      storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry)._to_hex
      state_subscribeStorage(rpc_id, [storage_key])
    end

    def derived_eth_call(rpc_id, to, data, at = nil)
      eth_call(
        rpc_id,
        [
          {
            'from' => nil, 'to' => to, 'data' => data
          },
          at
        ]
      )
    end
  end
end
