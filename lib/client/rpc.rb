# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

module Substrate
  module RPC
    class << self
      def build_json_rpc_body(method, params, id)
        {
          'id' => id,
          'jsonrpc' => '2.0',
          'method' => method,
          'params' => params.reject(&:nil?)
        }.to_json
      end

      def state_subscribeStorage(rpc_id, pallet_name, item_name, key = nil, registry = nil)
        storage_key = StorageHelper.encode_storage_key(pallet_name, item_name, key, registry).to_hex
        build_json_rpc_body('state_subscribeStorage', [[storage_key]], rpc_id)
      end

      def request(url, body)
        uri = URI(url)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = body
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.instance_of? URI::HTTPS
        res = http.request(req)
        # puts res unless res.is_a?(Net::HTTPSuccess)

        result = JSON.parse(res.body)
        raise result['error'] if result['error']

        result['result']
      end

      def json_rpc_call(method, params, url)
        body = build_json_rpc_body(method, params, 1)
        request(url, body)
      end

      def chain_getBlockHash(url, block_number = nil)
        json_rpc_call('chain_getBlockHash', [block_number], url)
      end

      def chain_getBlock(url, at = nil)
        json_rpc_call('chain_getBlock', [at], url)
      end

      def state_getRuntimeVersion(url, at = nil)
        json_rpc_call('state_getRuntimeVersion', [at], url)
      end

      def state_getMetadata(url, at = nil)
        json_rpc_call('state_getMetadata', [at], url)
      end

      def state_getStorage(url, key, at = nil)
        json_rpc_call('state_getStorage', [key, at], url)
      end

      def state_queryStorageAt(url, keys, at = nil)
        json_rpc_call('state_queryStorageAt', [keys, at], url)
      end

      def state_getKeysPaged(url, key, count, start_key = nil, at = nil)
        json_rpc_call('state_getKeysPaged', [key, count, start_key, at], url)
      end

      def eth_call(url, to, data, at_block_number = nil)
        json_rpc_call('eth_call', [
                        {
                          'from' => nil,
                          'to' => to,
                          'data' => data
                        },
                        at_block_number
                      ], url)
      end
    end
  end
end
