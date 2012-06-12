require "wego/version"

require "fiber"
require "eventmachine"

require "forwardable"
require "uri"
require "logger"
require "hashie"
require "rash"
require "hashie/lazy"
require "hashie/camel"
require "faraday"
require "multi_json"
require "active_support/core_ext/object/to_query"
require "uuid"

require 'wego/middleware'
require 'wego/flights'

module Wego
  # @see Wego::Configuration
  def configure(options = {})
    options = Hashie::Mash.new(options)

    unless options[:logger]
      logger = Logger.new(STDERR)
      logger.level = Logger::WARN
      options[:logger] = logger
    end

    yield options if block_given?
    config(options)
  end

  def config(options = {})
    if @configuration
      options = Hashie::Mash.new(options).to_hash
      Configuration.new(@configuration.to_hash.merge(options))
    else
      @configuration = Configuration.new(options)
    end
    @configuration = @configuration && @configuration.merge(options) || Configuration.new(options)
  end

  # @return [Logger]
  def log
    config.logger
  end
  module_function :configure, :config, :log

  class Configuration < Hashie::Dash
    property :api_key, :required => true
    property :logger
  end

  # Base class for all Wego errors
  class Error < StandardError
    class InvalidSession < Error
    end

    class InvalidParameter < Error
    end

    class Timeout < Error
    end
  end
end
