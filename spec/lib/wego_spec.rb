require 'spec_helper'

describe Wego do
  context 'configuration' do
    it 'should set api_key' do
      Wego.configure(:api_key => 'foo')
      Wego.config.api_key.should == 'foo'
    end

    it 'should yield a configuration' do
      Wego.configure {|c| c.api_key = 'foo'}
      Wego.config.api_key.should == 'foo'
    end

    it 'should require api_key' do
      # expect {Wego.configure}.to raise_error(ArgumentError)
    end
  end
end