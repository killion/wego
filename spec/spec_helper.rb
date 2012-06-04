require 'bundler/setup'
require 'wego'

Wego.configure(:api_key => ENV['WEGO_API']) if ENV['WEGO_API']

# require 'vcr'
# VCR.configure do |c|
#   c.cassette_library_dir = 'fixtures/vcr_cassettes'
#   c.hook_into :webmock
# end

# RSpec.configure do |c|
#   c.extend VCR::RSpec::Macros
# end