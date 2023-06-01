# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module Models
  class DefaultValueTest < SpannerAdapter::TestCase
    include TestHelpers::WithSeparateDatabase

    class DynamicItem < ActiveRecord::Base; end

    def test_dynamic_default_values
      connection.create_table :dynamic_items do |t|
        t.column :col_timestamp, :datetime, default: -> { "CURRENT_TIMESTAMP()" }
      end

      item = DynamicItem.create!
      item.reload
      assert(item.col_timestamp)
    end
  end
end
