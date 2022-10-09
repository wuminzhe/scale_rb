# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

module Substrate
  module RPC
    class << self
      def json_rpc_call(method, params, url)
        uri = URI(url)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = {
          'id' => 1,
          'jsonrpc' => '2.0',
          'method' => method,
          'params' => params.all?(nil) ? [] : params
        }.to_json
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.instance_of? URI::HTTPS
        res = http.request(req)
        # puts res unless res.is_a?(Net::HTTPSuccess)

        result = JSON.parse(res.body)
        raise result['error'] if result['error']

        result['result']
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
