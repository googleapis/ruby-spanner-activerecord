require "test_helper"

describe SpannerActiverecord do
  describe "#version" do
    it "check gem has a version number" do
      SpannerActiverecord::VERSION.wont_be_nil
    end
  end
end
