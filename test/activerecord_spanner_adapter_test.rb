# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

describe ActiveRecordSpannerAdapter do
  describe "#version" do
    it "check gem has a version number" do
      _(ActiveRecordSpannerAdapter::VERSION).wont_be_nil
    end
  end
end
