module Wego
  module Middleware
    autoload :Caching, 'wego/middleware/caching'
    autoload :Http,    'wego/middleware/http'
    autoload :Logging, 'wego/middleware/logging'
  end
end