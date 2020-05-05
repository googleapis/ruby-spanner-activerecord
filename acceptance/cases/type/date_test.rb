# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class DateTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "DATE", connection.type_to_sql(:date)
      end

      def test_set_date
        expected_date = ::Date.new 2020, 1, 31
        record = TestTypeModel.new start_date: expected_date

        assert_equal expected_date, record.start_date

        record.save!
        record.reload
        assert_equal expected_date, record.start_date
      end
    end
  end
end