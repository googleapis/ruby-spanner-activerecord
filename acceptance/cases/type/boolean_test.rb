# frozen_string_literal: true


require "test_helper"

module ActiveRecord
  module Type
    class BooleanTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "BOOL", connection.type_to_sql(:boolean)
      end

      def test_set_boolean_value_in_create
        record = TestTypeModel.create(active: true)
        record.reload
        assert_equal true, record.active

        record = TestTypeModel.create(active: false)
        record.reload
        assert_equal false, record.active
      end
    end
  end
end