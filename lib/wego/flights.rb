module Wego
  module Flights
    # @return [Search]
    def search(params = {})
      client.search(params)
    end

    # @return [Usage] or nil
    def usage
      client.usage
    end

    def client(options = {})
      @client ||= Client.new(:api_key => Wego.config.api_key)
    end
    module_function :search, :usage, :client

    class Client
      BASE_URL ||= "http://www.wego.com".freeze
      PREFIX   ||= "/api/flights".freeze

      # @param [Hash] options
      # @option options [Integer] :search_wait time in milliseconds to wait for polling results
      # @option options [String]  :api_key
      def initialize(options = {})
        @api_key = options[:api_key]
        @http = Faraday.new(BASE_URL) do |f|
          f.use HttpMiddleware, :api_key => options[:api_key]
          f.adapter :net_http # TODO: em_http here
        end
      end

      def usage
        res = @http.get '/usage.html'
        res.body && Usage.new(res.body)
      end

      class HttpMiddleware < Faraday::Middleware
        def initialize(app, options = {})
          @app     = app
          @options = options
        end

        def call(env)
          query = {:format => 'json', :apiKey => @options[:api_key]}.to_query
          env[:url].query = env[:url].query ? "#{env[:url].query}&#{query}" : query
          env[:url].path  = PREFIX + env[:url].path

          @app.call(env).on_complete do |env|
            # TODO: error handling here
            env[:body] = MultiJson.decode(env[:body])
          end
        rescue Faraday::Error::TimeoutError
          raise Wego::Error::Timeout
        end
      end
    end

    class Usage < Hashie::Rash
      def used
        api_usage_data.usage_count.value
      end

      def max
        api_usage_data.max_count.value
      end
    end

    class Search
      def itineraries
      end
    end

    class Itinerary
      def initialize
      end

      # @param [Boolean] refresh - do not return cached results
      # @return [Array] inbound Segments
      def inbound_segments(refresh = false)
      end

      # @param [Boolean] refresh - do not return cached results
      # @return [Array] outbound Segments
      def outbound_segments(refresh = false)
      end

      def booking_url
        # requires instanceId from Search object
      end

      # calling on detail methods will do a fetch and memoize the results
      class Segment
      end
    end
  end
end
