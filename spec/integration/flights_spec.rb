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
end