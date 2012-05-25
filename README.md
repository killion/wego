# Wego [![Build Status](https://secure.travis-ci.org/jch/rack-stream.png?branch=master)](http://travis-ci.org/jch/rack-stream)

ruby client to [Wego](http://www.wego.com/) API.

[Wego Flights Documentation](http://www.wego.com/api/flights/docs)
[Wego Hotels Documentation](http://www.wego.com/api/hotels/docs)

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
  :outbount_date => '2010-06-23',
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

Wego recommends waiting for at least 10 seconds before trying to pull results.
This gem will poll for results using a periodic EventMachine timer.
It is Fiber aware and can be used with em-synchrony.

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
