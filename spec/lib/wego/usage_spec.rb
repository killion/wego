describe Wego::Flights::Usage do
  let(:json) {
    MultiJson.decode(<<-JSON
    {"APIUsageData": {
        "usageCount": {
        "value": 0
        },
        "maxCount": {
        "value": 1000
        },
        "startTimeBucket": "20100612230038",
        "endTimeBucket": "20100613000038"
        }}
    JSON
    )
  }
  let(:subject) {described_class.new(json)}

  it 'should parse #used' do
    subject.used.should == 0
  end

  it 'should parse #max' do
    subject.max.should == 1000
  end
end