module Wego
  module Middleware
    class Http < Faraday::Middleware
      # @param [Hash] options
      # @option options [String] :api_key
      # @option options [String] :prefix url path prefix. ex: '/api/flights'
      def initialize(app, options = {})
        @app     = app
        @options = options
      end

      def call(env)
        query = {:format => 'json', :apiKey => @options[:api_key]}.to_query
        env[:url].query = env[:url].query ? "#{env[:url].query}&#{query}" : query
        env[:url].path  = @options[:prefix] + env[:url].path

        @app.call(env).on_complete do |env|
          if env[:status].to_s =~ /2\d\d/
            env[:body] = Hashie::Rash.new(MultiJson.decode(env[:body]))
            if e = env[:body].error
              raise Wego::Error.new "#{e} - #{env[:body].details}"
            end
          else
            error!(env)
          end
        end
      rescue Faraday::Error::TimeoutError
        raise Wego::Error::Timeout
      rescue MultiJson::DecodeError
        raise Wego::Error.new error!(env, "Invalid JSON response")
      end

      def error!(env, message="Wego API Exception")
        raise Wego::Error.new <<-FATAL

#{message}
#{"=" * message.size}
URL:
#{env[:url]}

Status:
#{env[:status]}

Body:
#{env[:body]}

FATAL
      end
    end
  end
end
