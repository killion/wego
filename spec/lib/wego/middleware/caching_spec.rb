require 'spec_helper'
require 'active_support'

describe Wego::Middleware::Caching do
  let(:response) {[200, {}, ['hello']]}
  let(:app) {lambda {|env| response}}
  let(:cache) {ActiveSupport::Cache.lookup_store(:memory_store)}
  let(:http) do
    Faraday.new do |b|
      b.use described_class, :store => cache
      b.adapter :rack, app
    end
  end

  it 'should call through to app' do
    app.should_receive(:call).and_return(response)
    http.get '/'
  end

  it 'should not call through to app if cached' do
    app.should_receive(:call).exactly(1).times.and_return(response)
    2.times.each {http.get '/'}
  end
end