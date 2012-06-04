source 'https://rubygems.org'

gemspec

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