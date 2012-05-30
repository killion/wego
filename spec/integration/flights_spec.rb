require 'spec_helper'

describe Wego::Flights do
  before :all do
    Wego.configure(:api_key => ENV['WEGO_API'])
  end

  it 'should report usage' do
    u = Wego::Flights.usage
    u.used.should be_kind_of(Fixnum)
    u.max.should  be_kind_of(Fixnum)
  end

  context 'search' do
    let(:client) {
      Wego::Flights::Client.new(:pull_wait => 4.0, :pull_count => 2)
    }

    let(:params) do
      {
        :from_location => 'LAX',
        :to_location   => 'SFO',
        :trip_type     => 'roundTrip',
        :cabin_class   => 'Economy',
        :inbound_date  => '2012-09-07',
        :outbound_date => '2012-09-05',
        :num_adults    => '1',
        :num_children  => '0'
      }
    end

    it 'should work' do
      search = client.search(params)
      search.instance_id.should_not be_nil
      search.rand.should_not be_nil
      search.itineraries.should_not be_empty
    end
  end
end