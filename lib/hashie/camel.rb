module Hashie
  class Camel < Mash
    # @param [Hash] options
    # @option options :except list of keys to not convert
    # @option options :upper  list of keys to start with lowercase. keys are lowercase by default
    def initialize(hash, options = {})
      @options = {:except => []}.merge(options)
      @options[:except].map! {|key| key.to_s}
      super hash
    end

    protected
    def convert_key(key)
      key = key.to_s.strip
      @options[:except].include?(key) ? key : camelize(key)
    end

    def camelize(key)
      if key =~ /_([a-z])/
        key.gsub(/_([a-z])/, $1.to_s.upcase)
      else
        key
      end
    end
  end
end