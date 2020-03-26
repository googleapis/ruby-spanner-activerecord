# frozen_string_literal: true


require "test_helper"

module ActiveRecord
  module Type
    class FloatTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_set_float_value_in_create
        record = TestTypeModel.create(weight: 123.32199)
        record.reload
        assert_equal 123.32199, record.weight
      end
    end
  end
end