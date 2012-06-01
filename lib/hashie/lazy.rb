module Hashie
  # Hash of great sloth
  #
  # Hashie::Mash.send(:include, Hashie::Lazy)
  #
  # local_variable = "I'm fat and lazy"
  #
  # hash = Hashie::Mash.new
  # hash.lazy :lazy_attribute do
  #   local_variable  # this block is evaluated later
  # end
  # hash.lazy_attribute  # "I'm fat and lazy"
  module Lazy
    def lazy(key, &blk)
      lazy_attributes << key.to_sym
      self[key] = blk
      self
    end

    def lazy_attributes
      @lazy_attributes ||= Set.new
    end

    def [](key)
      value = super
      lazy_attributes.include?(key.to_sym) ? value.call : value
    end

    def delete(key)
      lazy_attributes.delete(key.to_sym)
      super
    end
  end
end