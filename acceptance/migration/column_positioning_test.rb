# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ColumnPositioningTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def setup
        skip_test_table_create!
        super

        connection.create_table :testings, id: false do |t|
          t.column :first, :integer
          t.column :second, :integer
          t.column :third, :integer
        end
      end

      def teardown
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_column_positioning
        assert_equal %w(first second third), connection.columns(:testings).map(&:name)
      end

      def test_add_column_with_positioning
        connection.add_column :testings, :new_col, :integer
        assert_equal %w(first second third new_col), connection.columns(:testings).map(&:name)
      end
    end
  end
end