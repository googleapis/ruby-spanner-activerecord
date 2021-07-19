# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ColumnPositioningTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def setup
        skip_test_table_create!
        super

        connection.ddl_batch do
          connection.create_table :testing_columns_position, id: false, force: true do |t|
            t.column :first, :integer
            t.column :second, :integer
            t.column :third, :integer
          end
        end
      end

      def teardown
        connection.ddl_batch do
          connection.drop_table :testing_columns_position
        end rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_column_positioning
        assert_equal %w(first second third), connection.columns(:testing_columns_position).map(&:name)
      end

      def test_add_column_with_positioning
        connection.ddl_batch do
          connection.add_column :testing_columns_position, :fourth, :integer
        end
        assert_equal %w(first second third fourth), connection.columns(:testing_columns_position).map(&:name)
      end
    end
  end
end