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
    class TimeTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "TIMESTAMP", connection.type_to_sql(:time)
      end

      def test_assign_time
        expected_time = ::Time.now
        record = TestTypeModel.new start_time: expected_time

        assert_equal expected_time, record.start_time
      end

      def test_assign_empty_time
        record = TestTypeModel.new start_time: ""
        assert_nil record.start_time
      end

      def test_assign_nil_time
        record = TestTypeModel.new start_time: nil
        assert_nil record.start_time
      end

      def test_set_and_save_time
        expected_time = ::Time.now.utc
        record = TestTypeModel.create! start_time: expected_time

        assert_equal expected_time, record.start_time

        record.reload
        assert_equal expected_time, record.start_time
      end

      def test_date_time_string_value_with_subsecond_precision
        expected_time = ::Time.local 2017, 07, 4, 14, 19, 10, 897761

        string_value = "2017-07-04 14:19:10.897761"

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time.utc

        record.save!
        assert_equal expected_time, record.start_time.utc

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      end

      def test_date_time_with_string_value_with_non_iso_format
        string_value = "04/07/2017 2:19pm"
        expected_time = ::Time.local 2017, 07, 4, 14, 19

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time

        record.save!
        assert_equal expected_time, record.start_time.utc

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      end

      def test_default_year_is_correct
        expected_time = ::Time.utc(2000, 1, 1, 10, 30, 0)
        record = TestTypeModel.new start_time: { 4 => 10, 5 => 30 }

        assert_equal expected_time, record.start_time

        record.save!
        record.reload

        assert_equal expected_time, record.start_time
      end
    end
  end
end