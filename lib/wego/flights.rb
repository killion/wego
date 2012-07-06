module Wego
  module Flights
    autoload :Client, 'wego/flights/client'

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

    class Usage < Hashie::Rash
      WEGO_UTC_OFFSET ||= "+08:00".freeze

      def self.new_from_api response
        usage = Usage.new

        if response && response.api_usage_data
          usage.used_count = response.api_usage_data.usage_count.value
          usage.max_count = response.api_usage_data.max_count.value

          usage.start_time_bucket = Usage.wego_time_to_ruby_time(response.api_usage_data.start_time_bucket)
          usage.end_time_bucket = Usage.wego_time_to_ruby_time(response.api_usage_data.end_time_bucket)
        end

        usage
      end

      def usage_exceeded
        used_count >= max_count 
      end

      protected
      def self.wego_time_to_ruby_time wego_time
        #this is very messy. wego gives us a time like: "20120707045353". not only is it all in a string, but it's malaysia time (MYT, UTC + 8)

        year = wego_time[0, 4].to_i
        month = wego_time[4, 2].to_i
        day = wego_time[6, 2].to_i
        hour = wego_time[8, 2].to_i
        minute = wego_time[10, 2].to_i
        second = wego_time[12, 2].to_i

        Time.new(year, month, day, hour, minute, second, WEGO_UTC_OFFSET)
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
