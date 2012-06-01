require 'spec_helper'

describe Hashie::Lazy do
  subject {
    Class.new(Hashie::Rash) {
      include Hashie::Lazy
    }.new
  }

  it 'should eval lazy attributes' do
    local_scope = "foo"
    subject.lazy :lazy_attr do
      local_scope
    end
    subject.lazy_attr.should == local_scope
  end
end