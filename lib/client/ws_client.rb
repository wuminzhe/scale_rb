require 'async'
require 'async/websocket/client'
require 'async/http/endpoint'
require 'async/queue'
require 'json'

require_relative 'client_ext'

module ScaleRb
  class WsClient
    def self.start(url)

      Sync do |task|
        endpoint = Async::HTTP::Endpoint.parse(url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)

        Async::WebSocket::Client.connect(endpoint) do |connection|
          client = WsClient.new(connection)

          main_task = task.async do
            client.supported_methods = client.rpc_methods()['methods']
            yield client
          end

          while message = connection.read
            data = message.parse
            ScaleRb.logger.debug "Received message: #{data}"

            task.async do
              client.handle_response(data)
            end
          end
        ensure
          main_task&.stop
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
        raise "A subscribe method needs a block" unless block_given?

        subscribe(method, args) do |notification|
          yield notification['params']['result']
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
      if response.key?('id')
        @response_handler.handle(response)
      elsif response.key?('method')
        @subscription_handler.handle(response)
      else
        puts "Received an unknown message: #{response}"
      end
    end

    private

    def request(method, params = [])
      response_future = Async::Notification.new

      @response_handler.register(@request_id, proc { |response|
        response_future.signal(response['result'])
      })

      @connection.write({ jsonrpc: '2.0', id: @request_id, method: method, params: params }.to_json)

      @request_id += 1

      response_future.wait
    end
  end

  class ResponseHandler
    def initialize
      @handlers = {}
    end

    # handler: a proc with response data as param
    def register(id, handler)
      @handlers[id] = handler
    end

    def handle(response)
      id = response['id']
      if @handlers.key?(id)
        handler = @handlers[id]
        handler.call(response)
        @handlers.delete(id)
      else
        ScaleRb.logger.debug "Received a message with unknown id: #{response}"
      end
    end
  end

  class SubscriptionHandler
    def initialize
      @subscriptions = {}
    end

    def subscribe(subscription_id, handler)
      @subscriptions[subscription_id] = handler
    end

    def unsubscribe(subscription_id)
      @subscriptions.delete(subscription_id)
    end

    def handle(notification)
      subscription_id = notification.dig('params', 'subscription')
      return if subscription_id.nil?

      if @subscriptions.key?(subscription_id)
        @subscriptions[subscription_id].call(notification)
      else
        # the subscription_id may be not registered. 
        # in client.subscribe function, 
        #   ...
        #   subscription_id = request(method, params)
        #   @subscription_handler.subscribe(subscription_id, block)
        #   ...
        # the request(method, params) may be slow, so the subscription_id may be not registered when the first notification comes.
        sleep 0.01
        handle(notification)
      end
    end
  end

end
