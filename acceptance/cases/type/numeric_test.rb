# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class NumericTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "NUMERIC", connection.type_to_sql(:numeric)
      end

      def test_set_numeric_value_in_create
        record = TestTypeModel.create(price: 9750.99)
        record.reload
        assert_equal 9750.99, record.price
      end
    end
  end
end