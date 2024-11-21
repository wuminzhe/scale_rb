# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

require_relative 'client_share'

module ScaleRb
  class HttpClient
    include ClientShare
    attr_accessor :supported_methods

    def initialize(url)
      # check if the url is started with http or https
      url_regex = %r{^https?://}
      raise 'url format is not correct' unless url.match?(url_regex)

      @uri = URI.parse(url)
      @supported_methods = request('rpc_methods', [])[:methods]
    end

    def request(method, params = [])
      # don't check for rpc_methods, because there is no @supported_methods when initializing
      if method != 'rpc_methods' && !@supported_methods.include?(method)
        raise "Method `#{method}` is not supported. It should be in [#{@supported_methods.join(', ')}]."
      end

      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @uri.scheme == 'https'

      request = Net::HTTP::Post.new(@uri, 'Content-Type' => 'application/json')
      request.body = { jsonrpc: '2.0', method:, params:, id: Time.now.to_i }.to_json
      ScaleRb.logger.debug "—→ #{request.body}"

      # https://docs.ruby-lang.org/en/master/Net/HTTPResponse.html
      response = http.request(request)
      raise response unless response.is_a?(Net::HTTPOK)

      # parse response, make key symbol
      body = JSON.parse(response.body, symbolize_names: true)
      ScaleRb.logger.debug "←— #{body}"
      raise body[:error] if body[:error]

      body[:result]
    end

    def respond_to_missing?(*_args)
      true
    end

    def method_missing(method, *args)
      request(method.to_s, args)
    end
  end
end
