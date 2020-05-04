# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class DateTimeTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "TIMESTAMP", connection.type_to_sql(:datetime)
        assert_equal "TIMESTAMP", connection.type_to_sql(:datetime, limit: 128)
      end

      def test_datetime_seconds_precision_applied_to_timestamp
        expected_time = ::Time.now
        record = TestTypeModel.new start_datetime: expected_time

        assert_equal expected_time, record.start_datetime
        assert_equal expected_time.usec, record.start_datetime.usec
      end
    end
  end
end