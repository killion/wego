module Wego
  module Middleware
    # Caches API results by url
    class Caching < Faraday::Middleware
      extend Forwardable

      def_delegators :"@options[:store]", :read, :write

      # @param [Hash] options
      # @option options [Integer] :ttl time to live in seconds
      # @option options [ActiveSupport::Cache::Store] :store activesupport compatible cache store
      def initialize(app, options = {})
        super(app)
        @options = options
      end

      def call(env)
        response = read(env[:url])
        unless response
          response = @app.call(env)
          response.on_complete do |env|
            write(env[:url], response)
          end
        end
        response
      end
    end
  end
end