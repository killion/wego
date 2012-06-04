source 'https://rubygems.org'

gemspec

# needs this commit https://github.com/intridea/hashie/commit/a4778140a40604d1e5ea5e8b8319c3380cf9c801
# remove when this has been added to a version
gem 'hashie', :git => 'https://github.com/intridea/hashie.git'

group :development do
  gem 'rake'
  gem 'yard'

  gem 'guard'
  gem 'guard-bundler'
  gem 'guard-rspec'
end

group :development, :test do
  gem 'rspec', '~> 2'
  gem 'vcr'
  gem 'webmock'
end

group :debugger do
  gem 'debugger'
end

group :darwin do
  gem 'rb-fsevent'
  gem 'growl'
end