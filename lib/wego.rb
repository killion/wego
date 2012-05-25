require "wego/version"
require "hashie"
require "hashie/rash"

require 'wego/flights'

module Wego
  def configure(options = {})
    config(options)
    yield config if block_given?
    config
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
  module_function :configure, :config

  class Configuration < Hashie::Dash
    property :api_key, :required => true
  end

  # Base class for all Wego errors
  class Error < StandardError
    class InvalidSession < Error
    end

    class InvalidParameter < Error
    end
  end
end
