# Wego [![Build Status](https://secure.travis-ci.org/jch/rack-stream.png?branch=master)](http://travis-ci.org/jch/rack-stream)

ruby client to [Wego](http://www.wego.com/) API.

* [Wego Flights Documentation](http://www.wego.com/api/flights/docs)
* [Wego Hotels Documentation](http://www.wego.com/api/hotels/docs)

## Installation

Add this line to your application's Gemfile:

    gem 'wego'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wego

## Basic Example

```ruby
require 'wego'

Wego.configure do |config|
  config.api_key = 'yourapikey'
end

puts Wego::Flights.usage

search = Wego::Flights.search({
  :from_location => 'LAX',
  :to_location   => 'SFO',
  :trip_type     => 'roundTrip',
  :cabin_class   => 'Economy',
  :inbound_date  => '2010-06-26',
  :outbound_date => '2010-06-23',
  :num_adults    => 1,
  :ts_code       => 'a7557'
})

search.itineraries.each do |i|
  puts i.origin_country_code
  puts i.destination_country_code
  puts i.price.amount + i.price.currency_code
  puts i.booking_url

  i.outbound_segments.each do |s|
    puts s.flight_number.designator
    puts s.duration_in_min
  end
end
```

## Flight Results Fetch Interval

By default, this gem follows Wego's recommended polling interval:

> Wego recommends API consumers to do at least 10 polling with 5 seconds interval.

To change this, configure your own `Wego::Flights::Client`:

```ruby
client = Wego::Flights::Client.new(:pull_wait => 4.0, :pull_count => 2)
client.search({...})
```

This gem polls for results using a periodic EventMachine timer.
It is Fiber aware and can be used with em-synchrony.

## Logging

A ruby [Logger](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html)
can be configured to see intermediate steps:

```ruby
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

Wego.configure do |config|
  config.logger = logger
end
```

## Development

To run integration tests locally, set WEGO_API environment variable and run:

```sh
WEGO_API=yourapikey rspec spec/integration
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
