# frozen_string_literal: true

require_relative './rpc_request_builder'

module ScaleRb
  class AbstractWsClient
    extend RpcRequestBuilder
    attr_accessor :metadata, :registry

    def initialize
      @id = 0
      @metadata = nil
      @registry = nil
      @callbacks = {}
      @subscription_callbacks = {}
    end

    def send_json_rpc(_body)
      raise 'WsClient is a abstract base class for websocket client, please use its sub-class'
    end

    # changes: [
    #   [
    #     "0x26aa394eea5630e07c48ae0c9558cef780d41e5e16056765bc8461851072c9d7", # storage key
    #     "0x0400000000000000d887690900000000020000" # change
    #   ]
    # ]
    def process(resp)
      # handle id
      @callbacks[resp['id']]&.call(resp['id'], resp) if resp['id']

      # handle storage subscription
      return unless resp['params'] && resp['params']['subscription']
      return unless @metadata && @registry

      subscription = resp['params']['subscription']
      changes = resp['params']['result']['changes']
      block = resp['params']['result']['block']
      p "block: #{block}"

      return unless @subscription_callbacks[subscription]

      pallet_name, item_name, subscription_callback = @subscription_callbacks[subscription]
      storage_item = Metadata.get_storage_item(pallet_name, item_name, @metadata)
      storages = decode_storages(changes.map(&:last), storage_item, registry)
      subscription_callback.call(storages)
    end

    def get_metadata(callback = nil)
      if callback.nil?
        callback = lambda do |id, resp|
          return unless resp['id'] && resp['result']
          return if resp['id'] != id

          metadata_hex = resp['result']
          metadata = Metadata.decode_metadata(metadata_hex.strip._to_bytes)
          return unless metadata

          @metadata = metadata
          @registry = Metadata.build_registry(@metadata)
        end
      end

      id = bind_id_to(callback)
      body = state_getMetadata(id)
      send_json_rpc(body)
    end

    def subscribe_storage(pallet_name, item_name, subscription_callback, key = nil, registry = nil)
      callback = create_callback_for_subscribe_storage(pallet_name, item_name, subscription_callback)
      id = bind_id_to(callback)
      body = derived_state_subscribe_storage(id, pallet_name, item_name, key, registry)
      send_json_rpc(body)
    end

    private

    def bind_id_to(callback)
      @callbacks[@id] = callback
      old = @id
      @id += 1
      old
    end

    def decode_storages(datas, storage_item, registry)
      datas.map do |data|
        StorageHelper.decode_storage2(data, storage_item, registry)
      end
    end

    def create_callback_for_subscribe_storage(pallet_name, item_name, subscription_callback)
      lambda do |id, resp|
        return unless resp['id'] && resp['result']
        return if resp['id'] != id

        @subscription_callbacks[resp['result']] = [
          pallet_name,
          item_name,
          subscription_callback
        ]
      end
    end
  end
end
