# Copyright 2021 Google LLC
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
        assert_equal "JSON", connection.type_to_sql(:json)
      end

      def test_set_json
        expected_hash = {"key"=>"value", "array_key"=>%w[value1 value2]}
        record = TestTypeModel.new details: {key: "value", array_key: %w[value1 value2]}

        assert_equal expected_hash, record.details

        record.save!
        record.reload
        assert_equal expected_hash, record.details
      end
    end
  end
end