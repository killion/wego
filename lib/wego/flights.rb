module Wego
  module Flights
    # @return [Search]
    def search(options = {})
      Search.new
    end

    def usage(options = {})
      Usage.new
    end
    module_function :search, :usage

    class Client
      # @param [Hash] options
      # @option options [Integer] :search_wait time in milliseconds to wait for polling results
      def initialize(options = {})
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
