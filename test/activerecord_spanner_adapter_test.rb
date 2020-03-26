require "test_helper"

describe ActiveRecordSpannerAdapter do
  describe "#version" do
    it "check gem has a version number" do
      ActiveRecordSpannerAdapter::VERSION.wont_be_nil
    end
  end
end
