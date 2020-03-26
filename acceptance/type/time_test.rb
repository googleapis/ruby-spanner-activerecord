# frozen_string_literal: true


require "test_helper"

module ActiveRecord
  module Type
    class TimeTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_set_time
        expected_time = ::Time.now.utc
        record = TestTypeModel.create start_time: expected_time

        record.reload
        assert_equal expected_time, record.start_time
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