module Wego
  module Flights
    class Client
      BASE_URL ||= "http://www.wego.com".freeze
      PREFIX   ||= "/api/flights".freeze

      CACHE_PREFIX ||= "Wego_Flights_Client_".freeze
      CACHE_EXPIRES_IN ||= 60.minutes.freeze
      CACHED_METHODS ||= [:search, :details, :redirect].freeze

      USAGE_CACHE_KEY ||= "Wego_Client_Latest_Usage"
      USAGE_CACHE_EXPIRES_IN ||= 60.minutes.freeze

      #setup caching
      CACHED_METHODS.each do |method_name|
        define_method(method_name) do |query_params, &blk|
          inner_method_name = method_name.to_s + "!"

          unless @cache_store
            self.send(inner_method_name, query_params, &blk)
          else
            cache_key = Client.gen_cache_key query_params

            res = @cache_store.read(cache_key)

            unless res
              Wego.log.debug "#{method_name}, params #{query_params} - cache miss, so querying wego"

              if blk
                res = self.send(inner_method_name, query_params, &blk)
              else
                res = self.send(inner_method_name, query_params)
              end

              if method_name.to_s == "search" && res.try(:usage_exceeded)
                #if wego usage exceeded, only write to cache for the length of time it will be exceeded for
                @cache_store.write(cache_key, res, :expires_in => res.usage_available_in)
              else
                @cache_store.write(cache_key, res, :expires_in => CACHE_EXPIRES_IN)
              end
            else
              Wego.log.debug "#{method_name}, params #{query_params} - cache hit, using cached value"
            end
            res
          end
        end
      end

      attr_reader :options

      # @param [Hash] options
      # @option options [Float]   :pull_wait time in seconds to wait for polling results. default 5.0
      # @option options [Integer] :pull_count maximum number of times to pull while wego's still returning results. default 5
      # @option options [Integer] :pull_stop_no_new stop pulling after this number of times of no new results (this number of consecutive pulls that give no new results)
      # @option options [String]  :api_key default Wego.config.api_key
      # @option options [Hash]    :cache options for caching. [Wego::Flights::CacheMiddleware#initialize](Client/CacheMiddleware.html#initialize-instance_method)
      def initialize(options = {})
        @options = {
          :pull_wait  => 5.0,
          :pull_count => 5,
          :pull_stop_no_new => 3,
          :api_key    => Wego.config.api_key
        }.merge(options)

        @cache_store = options[:cache]

        @http = Faraday.new(BASE_URL) do |f|
          f.use Wego::Middleware::Http, :api_key => @options[:api_key], :prefix => PREFIX
          f.use Wego::Middleware::Logging, :logger => Wego.log
          f.adapter :net_http 
        end
      end

      def usage
        res = @http.get '/usage.html'
        res.body && Usage.new_from_api(res.body)
      end

      def update_usage
        @cache_store.write(USAGE_CACHE_KEY, usage, :expires_in => USAGE_CACHE_EXPIRES_IN) if @cache_store
      end

      def last_usage
        @cache_store.read(USAGE_CACHE_KEY) if @cache_store
      end

      # a Search object we return to communicates usage is exceeded
      def usage_exceeded_search
        search = Search.new
        search.usage_exceeded = true
        search.usage_available_in = last_usage.end_time_bucket - Time.now   #we expect last_usage to be in the cache
        search
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
      # @option params :language - optional - pass in the language preferred. If supported by the provider, users will be redirected to the site with the said lang.
      # @option params :country_site_code - optional - pass in the country site preferred. If supported by the provider, users will be redirected to the provider's corresponding country site.
      # @option params :monetized_partners - If this field is omitted, all partners results are returned. If true is given, only monetized partners are returned. If false is given, only non monetized partners are returned. Possible values: true, false
      # @param [blk] update_count_block - optional - call this block with the total number of results, as they're being loaded
      # @return [Search]
      # @see http://www.wego.com/api/flights/docs#api_startSearch
      def search!(params, &update_count_blk)
        params = Hashie::Camel.new(params)

        return usage_exceeded_search if last_usage.try(:usage_exceeded)

        res    = @http.get '/startSearch.html', params

        return usage_exceeded_search if last_usage && (res.body.request.usage.to_i + @options[:pull_count] > last_usage.max_count)

        pull_params = {
          :instance_id   => res.body.request.instance_id,
          :rand          => UUID.generate(:compact),
          :inbound_date  => params.inbound_date,
          :outbound_date => params.outbound_date
        }
        pull_params[:language] = params[:language] if params[:language]
        pull_params[:country_site_code] = params[:country_site_code] if params[:country_site_code]
        pull_params[:monetized_partners] = params[:monetized_partners] if params[:monetized_partners]

        pull(pull_params, update_count_blk)
      end

      # @param [Hash] params
      # @option params :instance_id - required Instance Id returned by the startSearch API request.
      # @option params :itinerary_id - required Itinerary Id in Itinerary response
      # @option params :outbound_date - required yyyy-MM-dd
      # @option params :inbound_date - yyyy-MM-dd
      # @return an Itinerary::Segment object (a Hashie::Rash) with keys outboundSegments and inboundSegments, values array of segment hashes as described in http://www.wego.com/api/flights/docs#api_details
      def details!(params)
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

      # @param [Hash] params
      # @option params :instance_id - required - Instance Id returned by the startSearch API request.
      # @option params :booking_code - required - obtained via /pull method from an Itinerary Object
      # @option params :dl_from - required - Departure Airport IATA code
      # @option params :dl_to - required - Destination Airport IATA code
      # @option params :provider_id - required - Provider Id obtained from an Itinerary Object
      # @option params :ts_code - required - always is a7557, for Wego to recognize the traffic is coming from public API. If custom ts_code is given, please use the given ts_code=VALUE .
      # @return [String] booking url
      def redirect!(params)
        params = Hashie::Camel.new(params)
        params[:ts_code] ||= 'a7557'
        params[:apiKey] ||= @options[:api_key]

        "#{BASE_URL}#{PREFIX}/redirect.html?#{params.to_query}"
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
      # @param [Blk] update_count_blk - optional - call this block with the total number of results, as they're being loaded
      # @private
      def pull(params, update_count_blk=nil)
        search = Search.new(params)
        params = Hashie::Camel.new(params)
        tries  = 0

        update_count_blk.call(0) unless update_count_blk.nil?

        pull_stop_no_new_count = 1    # counter for @options[:pull_stop_no_new]. it's a counter of how many duplicates there are (duplicate number of num_itins)
        num_itins_last_time = 0

        (1..@options[:pull_count]).each do |try|
          res = @http.get('/pull.html', params).body.response

          itineraries = res.itineraries.map do |rash|
            i = Itinerary.new(rash)
            i.instance_id = search.instance_id
            i
          end

          itineraries.reject! {|i| i.id.nil? }
            #sometimes wego returns empty itineraries

          # for some reason, += changes the type to Search,
          # and loses Itinerary as the type
          # search.itineraries += itineraries
          search.itineraries << itineraries
          search.itineraries.flatten!

          num_itins = search.itineraries.count

          update_count_blk.call(num_itins) unless update_count_blk.nil?

          if num_itins_last_time == num_itins
            pull_stop_no_new_count += 1 
          else
            pull_stop_no_new_count = 1
          end

          break if pull_stop_no_new_count == @options[:pull_stop_no_new] || !res.pending_results

          num_itins_last_time = num_itins

          if try < @options[:pull_count]
            #don't sleep the last time
            sleep @options[:pull_wait]
          end
        end

        search
      end

      def self.gen_cache_key query_params
         CACHE_PREFIX + Digest::MD5.hexdigest(Marshal.dump(query_params.sort))
      end
    end
  end
end
