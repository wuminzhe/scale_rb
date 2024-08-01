require 'async'
require 'async/websocket/client'
require 'async/http/endpoint'

require_relative 'client_ext'

module ScaleRb
  class WsClient
    # @param [string] url
    def self.start(url)

      Sync do |task|
        endpoint = Async::HTTP::Endpoint.parse(url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)

        Async::WebSocket::Client.connect(endpoint) do |connection|
          client = WsClient.new(connection)

          recv_task = task.async do
            while message = connection.read
              data = message.parse
              ScaleRb.logger.debug "Received message: #{data}"

              client.handle_response(data)
            end
          end

          client.supported_methods = client.rpc_methods()[:methods]
          yield client

          recv_task.wait
        ensure
          recv_task&.stop
        end
      end

    end
  end
end

module ScaleRb
  class WsClient
    include ClientExt
    attr_accessor :supported_methods

    def initialize(connection)
      @connection = connection
      @response_handler = ResponseHandler.new
      @subscription_handler = SubscriptionHandler.new
      @request_id = 1
    end

    def respond_to_missing?(method, *)
      @supported_methods.include?(method.to_s)
    end

    def method_missing(method, *args)
      method = method.to_s
      ScaleRb.logger.debug "#{method}(#{args.join(', ')})"

      # why not check 'rpc_methods', because there is no @supported_methods when initializing
      if method != 'rpc_methods' && !@supported_methods.include?(method)
        raise "Method `#{method}` is not supported. It should be in [#{@supported_methods.join(', ')}]."
      end

      if method.include?('unsubscribe')
        unsubscribe(method, args[0])
      elsif method.include?('subscribe')
        raise 'A subscribe method needs a block' unless block_given?

        subscribe(method, args) do |notification|
          yield notification[:params][:result]
        end
      else
        request(method, args)
      end
    end

    def subscribe(method, params = [], &block)
      return unless method.include?('subscribe')
      return if method.include?('unsubscribe')

      subscription_id = request(method, params)
      @subscription_handler.subscribe(subscription_id, block)
      subscription_id
    end

    def unsubscribe(method, subscription_id)
      return unless method.include?('unsubscribe')

      if @subscription_handler.unsubscribe(subscription_id)
        request(method, [subscription_id])
      end
    end

    def handle_response(response)
      if response.key?(:id)
        @response_handler.handle(response)
      elsif response.key?(:method)
        @subscription_handler.handle(response)
      else
        puts "Received an unknown message: #{response}"
      end
    end

    private

    def request(method, params = [])
      response_future = Async::Notification.new

      @response_handler.register(@request_id, proc { |response|
        response_future.signal(response[:result])
      })

      request = { jsonrpc: '2.0', id: @request_id, method: method, params: params }
      ScaleRb.logger.debug "Sending request: #{request}"
      @connection.write(request.to_json)

      @request_id += 1
      response_future.wait
    end
  end

  class ResponseHandler
    def initialize
      @callbacks = {}
    end

    # callback: a proc with response data as param
    def register(id, callback)
      @callbacks[id] = callback
    end

    def handle(response)
      id = response[:id]
      if @callbacks.key?(id)
        callback = @callbacks[id]
        callback.call(response)
        @callbacks.delete(id)
      else
        ScaleRb.logger.debug "Received a message with unknown id: #{response}"
      end
    end
  end

  class SubscriptionHandler
    def initialize
      @callbacks = {}
    end

    def subscribe(subscription_id, callback)
      @callbacks[subscription_id] = callback
    end

    def unsubscribe(subscription_id)
      @callbacks.delete(subscription_id)
    end

    def handle(notification)
      subscription_id = notification.dig(:params, :subscription)
      return if subscription_id.nil?

      if @callbacks.key?(subscription_id)
        @callbacks[subscription_id].call(notification)
      end
    end
  end

end
