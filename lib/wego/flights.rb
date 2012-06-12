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

    # @return [Client]
    def client(options = {})
      @client ||= Client.new({:api_key => Wego.config.api_key}.merge(options))
    end
    module_function :search, :usage, :client

    class Client
      BASE_URL ||= "http://www.wego.com".freeze
      PREFIX   ||= "/api/flights".freeze

      attr_reader :options

      # @param [Hash] options
      # @option options [Float]   :pull_wait time in seconds to wait for polling results. default 4.0
      # @option options [Integer] :pull_count number of times to pull. default 2
      # @option options [String]  :api_key default Wego.config.api_key
      # @option options [Hash]    :cache options for caching. [Wego::Flights::CacheMiddleware#initialize](Client/CacheMiddleware.html#initialize-instance_method)
      def initialize(options = {})
        @options = {
          :pull_wait  => 4.0,
          :pull_count => 2,
          :api_key    => Wego.config.api_key
        }.merge(options)

        @http = Faraday.new(BASE_URL) do |f|
          f.use Wego::Middleware::Caching, options[:cache] if options[:cache]
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
      # @option params :from_location - required - 3-letter IATA airport code (e.g. SIN)
      # @option params :to_location - required - 3-letter IATA airport code (e.g. BKK)
      # @option params :trip_type - required - Possible Values: oneWay, roundTrip
      # @option params :cabin_class - required - Possible Values: Economy, Business, First
      # @option params :inbound_date - yyyy-MM-dd (not required for oneWay flights)
      # @option params :outbound_date - required - yyyy-MM-dd
      # @option params :num_adults - required - 1- 9
      # @option params :num_children - required - 0- 9
      # @option params :ts_code - optional - always is a7557, for Wego to recognize the traffic is coming from public API. If custom `ts_code` is given, please use the given `ts_code=VALUE`.
      # @option params :monetized_partners - If this field is omitted, all partners results are returned. If true is given, only monetized partners are returned. If false is given, only non monetized partners are returned. Possible values: true, false
      # @return [Search]
      # @see http://www.wego.com/api/flights/docs#api_startSearch
      def search(params)
        params = Hashie::Camel.new(params)
        res    = @http.get '/startSearch.html', params

        pull_params = {
          :instance_id   => res.body.request.instance_id,
          :rand          => UUID.generate(:compact),
          :inbound_date  => params.inbound_date,
          :outbound_date => params.outbound_date
        }
        pull_params[:monetized_partners] = params[:monetized_partners] if params[:monetized_partners]
        pull(pull_params)
      end

      protected

      # You should not need to call this method directly, #search will
      # call #pull for you.
      #
      # @param [Hash] params
      # @option params instanceId - required - Instance Id returned by the startSearch API request.
      # @option params rand - required - a random alpha-numeric value. The rand parameter used is used in conjunction with the instanceId parameter to form a unique key that will keep track of number of results returned to the client for a given session. Important: If you wish to start polling from the very first result then issue a new rand value, otherwise continue using the same rand till you reach the end of result list.
      # @option params monetized_partners - If this field is omitted, all partners results are returned. If true is given, only monetized partners are returned. If false is given, only non monetized partners are returned. Possible values: true, false
      # @see http://www.wego.com/api/flights/docs#api_pull
      # @private
      def pull(params)
        with_event_machine do
          search = Search.new(params)
          params = Hashie::Camel.new(params)
          tries  = 0
          fiber  = Fiber.current

          poll_timer = EM.add_periodic_timer(@options[:pull_wait]) do
            res = @http.get('/pull.html', params).body.response
            itineraries = res.itineraries.map do |rash|
              i = Itinerary.new(rash)
              i.instance_id = search.instance_id
              i.lazy(:segments) do
                # TODO: /details API requires :outbound_date and
                # :inbound_date, but does not provide them easily
                # in the itinerary results from /pull.html
                segments = details({
                  :instance_id   => i.instance_id,
                  :itinerary_id  => i.id,
                  :outbound_date => search.outbound_date,
                  :inbound_date  => search.inbound_date
                })
                i.cached_segments ||= segments
                i.cached_segments
              end
              i
            end

            # TODO: sometimes result hash is blank
            # for some reason, += changes the type to Search,
            # and loses Itinerary as the type
            # search.itineraries += itineraries
            search.itineraries << itineraries
            search.itineraries.flatten!

            tries += 1
            if !res.pending_results || tries >= @options[:pull_count]
              poll_timer.cancel
              fiber.resume search
            end
          end

          Fiber.yield  # populated Search object
        end
      end

      # @param [Hash] params
      # @option params :instance_id - required Instance Id returned by the startSearch API request.
      # @option params :itinerary_id - required Itinerary Id in Itinerary response
      # @option params :outbound_date - required yyyy-MM-dd
      # @option params :inbound_date - yyyy-MM-dd
      def details(params)
        params   = Hashie::Camel.new(params)
        segments = @http.get('/details.html', params).body.details

        # set type to Segment
        [:inbound_segments, :outbound_segments].each do |key|
          segments[key] = segments[key].list.map {|s|
            Itinerary::Segment.new(s)
          }
        end
        segments
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
              env[:body] = Hashie::Rash.new(MultiJson.decode(env[:body]))
              if e = env[:body].error
                raise Wego::Error.new "#{e} - #{env[:body].details}"
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

    class Search < Hashie::Rash
      def initialize(source = nil, default = nil, &blk)
        super
        self.itineraries ||= []
      end
    end

    class Itinerary < Hashie::Rash
      include Hashie::Lazy

      def inbound_segments
        # use [] to read underlying value
        segments[:inbound_segments]
      end

      def outbound_segments
        # use [] to read underlying value
        segments[:outbound_segments]
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
