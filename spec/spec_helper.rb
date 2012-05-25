require 'wego'

Wego.configure(:api_key => ENV['WEGO_API']) if ENV['WEGO_API']