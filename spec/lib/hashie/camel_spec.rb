require 'spec_helper'

describe Hashie::Camel do
  subject {
    Hashie::Camel.new({
      :api_key => 'foo',
      :ts_code => 'baz'
    }, nil, :except => [:ts_code]).to_hash
  }

  it 'should camelize' do
    subject['apiKey'].should == 'foo'
  end

  it 'should skip keys' do
    subject['ts_code'].should == 'baz'
  end
end