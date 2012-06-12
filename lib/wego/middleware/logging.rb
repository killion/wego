module Wego
  module Middleware
    class Logging < Faraday::Middleware
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
end