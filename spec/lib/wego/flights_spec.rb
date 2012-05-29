require 'spec_helper'

describe Wego::Flights do
  before :all do
    Wego.configure :api_key => 'foo'
  end
end
