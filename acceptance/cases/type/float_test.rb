# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class FloatTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "FLOAT64", connection.type_to_sql(:float)
      end

      def test_set_float_value_in_create
        record = TestTypeModel.create(weight: 123.32199)
        record.reload
        assert_equal 123.32199, record.weight
      end
    end
  end
end