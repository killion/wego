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
