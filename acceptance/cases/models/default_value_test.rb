# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module Models
  class DefaultValueTest < SpannerAdapter::TestCase
    include TestHelpers::WithSeparateDatabase

    class LiteralValue < ActiveRecord::Base; end
    class ExpressionValue < ActiveRecord::Base; end

    def test_literal_default_values
      default = OpenStruct.new(
        col_string: "default",
        col_int64: 123,
        col_float64: 1.23,
        col_numeric: BigDecimal("1.23"),
        col_bool: true,
        col_date: Date.new(2023, 5, 9),
        col_timestamp: DateTime.new(2023, 5, 9, 1, 2, 3),
      )

      connection.create_table :literal_values do |t|
        t.column :col_string, :string, default: default.col_string
        t.column :col_int64, :bigint, default: default.col_int64
        t.column :col_float64, :float, default: default.col_float64
        t.column :col_numeric, :numeric, default: default.col_numeric
        t.column :col_bool, :boolean, default: default.col_bool
        t.column :col_date, :date, default: default.col_date
        t.column :col_timestamp, :datetime, default: default.col_timestamp
      end

      item = LiteralValue.new
      default.each_pair { |col, expected| assert_equal(expected, item[col]) }
      item.save!
      default.each_pair { |col, expected| assert_equal(expected, item[col]) }
      item.reload
      default.each_pair { |col, expected| assert_equal(expected, item[col]) }
    end

    def test_expression_default_values
      connection.create_table :expression_values do |t|
        t.column :col_numeric, :numeric, default: -> { "NUMERIC '1.23'" }
        t.column :col_timestamp, :datetime, default: -> { "CURRENT_TIMESTAMP()" }
      end

      item = ExpressionValue.create!
      item.reload
      assert_equal(BigDecimal("1.23"), item.col_numeric)
      assert(item.col_timestamp)
    end
  end
end
