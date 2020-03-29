# frozen_string_literal: true


require "test_helper"

module ActiveRecord
  module Type
    class StringTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_set_string_in_create
        description = "a" * 1000
        name = "Test name"
        record = TestTypeModel.create(description: description, name: name)
        record.reload

        assert_equal description, record.description
        assert_equal name, record.name
      end

      def test_set_string_with_max_limit_in_create
        str = "a" * 256

        assert_raise(ActiveRecord::StatementInvalid) {
          TestTypeModel.create(name: str)
        }
      end
    end
  end
end