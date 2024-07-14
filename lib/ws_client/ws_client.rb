require 'async'
require 'async/websocket/client'
require 'async/http/endpoint'
require 'async/queue'
require 'json'

module ScaleRb
  class WsClient
    attr_accessor :supported_methods

    def initialize
      @queue = Async::Queue.new
      @response_handler = ResponseHandler.new
      @subscription_handler = SubscriptionHandler.new
      @request_id = 1
    end

    def send_request(method, params = [])
      if method != 'rpc_methods' && !@supported_methods.include?(method)
        raise "Method `#{method}` is not supported. It should be in [#{@supported_methods.join(', ')}]."
      end

      response_future = Async::Notification.new

      @response_handler.register(@request_id, proc { |response|
        # this is running in the main task
        response_future.signal(response['result'])
      })

      request = JsonRpcRequest.new(@request_id, method, params)
      @queue.enqueue(request)

      @request_id += 1

      response_future.wait
    end

    def subscribe(method, params = [], &block)
      return unless method.include?('subscribe')

      subscription_id = send_request(method, params)
      @subscription_handler.subscribe(subscription_id, block)
      subscription_id
    end

    def unsubscribe(method, subscription_id)
      result = send_request(method, [subscription_id])
      @subscription_handler.unsubscribe(subscription_id)
      result
    end

    def next_request
      @queue.dequeue
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

    def respond_to_missing?(*_args)
      true
    end

    def method_missing(method, *args)
      method = method.to_s
      if method.include?('unsubscribe')
        unsubscribe(method, args[0])
      elsif method.include?('subscribe')
        raise "A subscribe method needs a block" unless block_given?

        subscribe(method, args) do |notification|
          yield notification['params']['result']
        end
      else
        send_request(method, args)
      end
    end

    def self.start(url)
      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
        client = WsClient.new

        task.async do
          Async::WebSocket::Client.connect(endpoint) do |connection|
            Async do
              while request = client.next_request
                ScaleRb.logger.debug "Sending request: #{request.to_json}"
                connection.write(request.to_json)
              end
            end

            # inside main task
            while message = connection.read
              data = JSON.parse(message)
              ScaleRb.logger.debug "Received message: #{data}"

              # 可以简单的理解为，这里的handle_response就是通知wait中的send_request，可以继续了.
              Async do
                client.handle_response(data)
              rescue => e
                ScaleRb.logger.error "#{e.class}: #{e.message}"
                ScaleRb.logger.error e.backtrace.join("\n")
                task.stop
              end
            end
          rescue => e
            ScaleRb.logger.error "#{e.class}: #{e.message}"
            ScaleRb.logger.error e.backtrace.join("\n")
          ensure
            task.stop
          end
        end

        task.async do
          client.supported_methods = client.send_request('rpc_methods')['methods']
          yield client
        rescue => e
          ScaleRb.logger.error "#{e.class}: #{e.message}"
          ScaleRb.logger.error e.backtrace.join("\n")
          task.stop
        end
      end
    end
  end

  class JsonRpcRequest
    attr_reader :id, :method, :params

    def initialize(id, method, params = {})
      @id = id
      @method = method
      @params = params
    end

    def to_json(*_args)
      { jsonrpc: '2.0', id: @id, method: @method, params: @params }.to_json
    end

    # def to_s
    #   to_json
    # end
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
      if subscription_id && @subscriptions.key?(subscription_id)
        @subscriptions[subscription_id].call(notification)
      else
        ScaleRb.logger.debug "Received a notification with unknown subscription id: #{notification}"
      end
    end
  end

end
