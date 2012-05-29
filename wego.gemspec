# -*- encoding: utf-8 -*-
require File.expand_path('../lib/wego/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jerry Cheung"]
  gem.email         = ["jch@whatcodecraves.com"]
  gem.description   = %q{ruby client to Wego API}
  gem.summary       = %q{ruby client to Wego API}
  gem.homepage      = "https://github.com/jch/wego"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "wego"
  gem.require_paths = ["lib"]
  gem.version       = Wego::VERSION

  gem.add_dependency "hashie"
  gem.add_dependency "rash"
  gem.add_dependency "faraday"
  gem.add_dependency "multi_json"
  gem.add_dependency "activesupport"
  gem.add_dependency "eventmachine"
end
