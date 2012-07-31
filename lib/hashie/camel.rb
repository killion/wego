module Hashie
  class Camel < Mash
    # @param [Hash] options
    # @option options :except list of keys to not convert
    def initialize(hash = nil, default = nil, options = {}, &blk)
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
        key.gsub(/_([a-z])/){|b| b[1..1].upcase}
      else
        key
      end
    end
  end
end
