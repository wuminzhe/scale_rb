# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require_relative './rpc_request_builder'
require_relative './http_client_metadata'
require_relative './http_client_storage'

# TODO: method_name = cmd.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
module ScaleRb
  module HttpClient
    extend RpcRequestBuilder

    class << self
      def request(url, body, tries = 0)
        ScaleRb.logger.debug "url: #{url}"
        ScaleRb.logger.debug "body: #{body}"
        uri = URI(url)
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = body
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.instance_of? URI::HTTPS
        res = http.request(req)

        raise res.class.name unless res.is_a?(Net::HTTPSuccess)

        result = JSON.parse(res.body)
        ScaleRb.logger.debug result
        raise result['error']['message'] if result['error']

        result['result']
      rescue StandardError => e
        raise e unless tries < 5

        ScaleRb.logger.error e.message
        ScaleRb.logger.error 'retry after 5 seconds...'
        sleep 5
        request(url, body)
      end

      def json_rpc_call(url, method, *params)
        body = build_json_rpc_body(method, params, Time.now.to_i)
        request(url, body)
      end

      def respond_to_missing?(*_args)
        true
      end

      def method_missing(method, *args)
        ScaleRb.logger.debug "#{method}(#{args.join(', ')})"
        # check if the first argument is a url
        url_regex = %r{^https?://}
        raise 'url format is not correct' unless args[0].match?(url_regex)

        url = args[0]
        raise NoMethodError, "undefined rpc method `#{method}'" unless rpc_methods(url).include?(method.to_s)

        json_rpc_call(url, method, *args[1..])
      end

      def rpc_methods(url)
        result = json_rpc_call(url, 'rpc_methods', [])
        result['methods']
      end
    end
  end
end

# https://polkadot.js.org/docs/substrate/rpc/
#
# Examples:
# # Get all supported rpc methods
# ScaleRb::HttpClient.rpc_methods("https://rpc.darwinia.network")
#
# # eth_blockNumber
# ScaleRb::HttpClient.eth_blockNumber("https://rpc.darwinia.network")
#
# # system_name
# ScaleRb::HttpClient.system_name("https://rpc.darwinia.network")
#
# # chain_getHead
# ScaleRb::HttpClient.chain_getHead("https://rpc.darwinia.network")
#
# # state_getMetadata of darwinia block #1582
# ScaleRb::HttpClient.state_getMetadata(
#   "https://rpc.darwinia.network",
#   "0xb5a4f16d0feba7531e75315432b4d31a5b918987e026437890a2cbf5b8d9956d"
# )
#
# # eth_getBalance of address 0x0000000000000000000000000000000000000000 at block #1582
# ScaleRb::HttpClient.eth_getBalance(
#   "https://rpc.darwinia.network",
#   "0x0000000000000000000000000000000000000000",
#   1582
# )
