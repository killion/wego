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

      attr_reader :options

      # @param [Hash] options
      # @option options [Float]   :pull_wait time in seconds to wait for polling results. default 5.0
      # @option options [Integer] :pull_count number of times to pull. default 10
      # @option options [String]  :api_key. default Wego.config.api_key
      def initialize(options = {})
        @options = {
          :pull_wait  => 5.0,
          :pull_count => 10,
          :api_key    => Wego.config.api_key
        }.merge(options)
        @http = Faraday.new(BASE_URL) do |f|
          f.use HttpMiddleware, :api_key => @options[:api_key]
          f.use Logger, :logger => Wego.log
          f.adapter :net_http # TODO: em_http here
        end
      end

      def usage
        res = @http.get '/usage.html'
        res.body && Usage.new(res.body)
      end

      # @param [Hash] params - can be camelCase or under_score
      # @option params formLocation - required - 3-letter IATA airport code (e.g. SIN)
      # @option params toLocation - required - 3-letter IATA airport code (e.g. BKK)
      # @option params tripType - required - Possible Values: oneWay, roundTrip
      # @option params cabinClass - required - Possible Values: Economy, Business, First
      # @option params inboundDate - yyyy-MM-dd (not required for oneWay flights)
      # @option params outBoundDate - required - yyyy-MM-dd
      # @option params numAdults - required - 1- 9
      # @option params numChildren - required - 0- 9
      # @option params ts_code - optional - always is a7557, for Wego to recognize the traffic is coming from public API. If custom `ts_code` is given, please use the given `ts_code=VALUE`.
      # @option params monetized_partners - If this field is omitted, all partners results are returned. If true is given, only monetized partners are returned. If false is given, only non monetized partners are returned. Possible values: true, false
      # @return [Search]
      # @see http://www.wego.com/api/flights/docs#api_startSearch
      def search(params)
        params = Hashie::Camel.new(params)
        res    = @http.get '/startSearch.html', params

        pull_params = {
          :instance_id => res.body.request.instance_id,
          :rand        => UUID.generate(:compact)
        }
        pull_params[:monetized_partners] = params[:monetized_partners] if params[:monetized_partners]
        pull(pull_params)
      end

      protected

      # @param [Hash] params
      # @option params instanceId - required - Instance Id returned by the startSearch API request.
      # @option params rand - required - a random alpha-numeric value. The rand parameter used is used in conjunction with the instanceId parameter to form a unique key that will keep track of number of results returned to the client for a given session. Important: If you wish to start polling from the very first result then issue a new rand value, otherwise continue using the same rand till you reach the end of result list.
      # @option params monetized_partners - If this field is omitted, all partners results are returned. If true is given, only monetized partners are returned. If false is given, only non monetized partners are returned. Possible values: true, false
      # @see http://www.wego.com/api/flights/docs#api_pull
      def pull(params)
        with_event_machine do
          params = Hashie::Camel.new(params)
          search = Search.new
          tries  = 0
          fiber  = Fiber.current

          poll_timer = EM.add_periodic_timer(@options[:pull_wait]) do
            res = @http.get('/pull.html', params).body.response

            # TODO: sometimes result hash is blank
            search.itineraries += res.itineraries.map {|i| Itinerary.new(i)}
            tries += 1
            if !res.pending_results || tries >= @options[:pull_count]
              poll_timer.cancel
              fiber.resume search
            end
          end

          Fiber.yield  # populated Search object
        end
      end

      def with_event_machine(&blk)
        # Note: avoid synchronous logging or other synchronous actions
        # in the following block
        result = nil
        if !EM.reactor_running?
          EM.run do
            Fiber.new {
              result = blk.call
              EM.stop
            }.resume
          end
        else
          Fiber.new {
            result = blk.call
          }.resume
        end
        result
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
            if env[:status].to_s =~ /2\d\d/
              env[:body] = Hashie::Rash.new(MultiJson.decode(env[:body]), Hashie::Mash.new)
              if e = env[:body].response.error
                Wego.log.error e
              end
            else
              raise Wego::Error.new <<-FATAL

Wego API Exception
==================
  URL:
  #{env[:url]}

  Status:
  #{env[:status]}

  Body:
  #{env[:body]}

              FATAL
            end
          end
        rescue Faraday::Error::TimeoutError
          raise Wego::Error::Timeout
        end
      end

      class Logger < Faraday::Middleware
        def initialize(app, options = {})
          @app     = app
          @options = options
        end

        def call(env)
          log.info "#{env[:method].to_s.upcase} #{env[:url]}"
          log.debug env[:body] if env[:body]
          log.debug "="*80
          @app.call(env).on_complete do |env|
            log.debug env[:status]
            log.debug env[:body]
          end
        end

        protected
        def log
          @options[:logger]
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
      attr_accessor :itineraries

      def initialize
        @itineraries = []
      end
    end

    class Itinerary < Hashie::Rash
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
      class Segment < Hashie::Rash
      end
    end
  end
end
