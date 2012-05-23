require 'spec_helper'

describe Wego::Flights do
  it 'should build Search objects' do
    described_class.search.should be_kind_of(Wego::Flights::Search)
  end

  it 'should build Usage objects' do
    described_class.usage.should be_kind_of(Wego::Flights::Usage)
  end
end