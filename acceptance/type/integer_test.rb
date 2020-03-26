# frozen_string_literal: true


require "test_helper"

module ActiveRecord
  module Type
    class IntegerTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_set_integer_value_in_create
        record = TestTypeModel.create(length: 123)

        record.reload
        assert_equal 123, record.length
      end

      def test_casting_models
        type = Type::Integer.new

        record = TestTypeModel.create(name: "Google")
        assert_nil type.cast(record)
      end

      def test_values_out_of_range_can_re_assigned
        model = TestTypeModel.new
        model.length = 2147483648
        model.length = 1

        assert_equal 1, model.length
      end
    end
  end
end