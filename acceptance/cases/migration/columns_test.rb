# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ColumnsTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def test_rename_column
        error = assert_raise ActiveRecordSpannerAdapter::NotSupportedError do
          rename_column "test_models", :hat_name, :cap_name
        end

        assert_equal "rename column not supported.", error.message
      end

      def test_change_column_default_value
        error = assert_raise ActiveRecordSpannerAdapter::NotSupportedError do
          change_column_default "test_models", :hat_name, "hat"
        end

        assert_equal "change column with default value not supported.", error.message
      end

      def test_remove_column_with_index
        add_column "test_models", :hat_name, :string
        add_index :test_models, :hat_name

        assert_equal 1, connection.indexes("test_models").size
        remove_column "test_models", "hat_name"
        assert_equal 0, connection.indexes("test_models").size
      end

      def test_remove_column_with_multi_column_index
        add_column "test_models", :hat_size, :integer
        add_column "test_models", :hat_style, :string, limit: 100
        add_index "test_models", ["hat_style", "hat_size"], unique: true

        assert_equal 1, connection.indexes("test_models").size
        remove_column "test_models", "hat_size"

        assert_equal [], connection.indexes("test_models").map(&:name)
      end

      def test_change_type_of_not_null_column
        change_column "test_models", "updated_at", :datetime, null: false
        change_column "test_models", "updated_at", :datetime, null: false

        TestModel.reset_column_information
        assert_equal false, TestModel.columns_hash["updated_at"].null
      ensure
        change_column "test_models", "updated_at", :datetime, null: true
      end

      def test_change_column_nullability
        add_column "test_models", "funny", :boolean
        assert TestModel.columns_hash["funny"].null, "Column 'funny' must initially allow nulls"

        change_column "test_models", "funny", :boolean, null: false

        TestModel.reset_column_information
        assert_not TestModel.columns_hash["funny"].null, "Column 'funny' must *not* allow nulls at this point"

        change_column "test_models", "funny", :boolean, null: true
        TestModel.reset_column_information
        assert TestModel.columns_hash["funny"].null, "Column 'funny' must allow nulls again at this point"
      end

      def test_change_column
        # Only string and binary allows to change types
        add_column "test_models", "name", :string

        old_columns = connection.columns TestModel.table_name

        assert old_columns.find { |c| c.name == "name" && c.type == :string }

        change_column "test_models", "name", :binary

        new_columns = connection.columns TestModel.table_name

        assert_not new_columns.find { |c| c.name == "name" && c.type == :string }
        assert new_columns.find { |c| c.name == "name" && c.type == :binary }
      end

      def test_change_column_with_custom_index_name
        add_column :test_models, :category, :string
        add_index :test_models, :category, name: "test_models_categories_idx", order: { category: :desc}

        assert_equal ["test_models_categories_idx"], connection.indexes("test_models").map(&:name)
        change_column "test_models", "category", :string, null: false

        assert column_exists?(:test_models, :category, :string, null: false)
        indexes = connection.indexes("test_models")
        assert_equal ["test_models_categories_idx"], indexes.map(&:name)
        assert_equal({ category: :desc }, indexes.first.orders)
      end

      def test_change_column_with_long_index_name
        table_name_prefix = "test_models_"
        long_index_name = table_name_prefix + ("x" * (connection.allowed_index_name_length - table_name_prefix.length))
        add_column "test_models", "category", :string
        add_index :test_models, :category, name: long_index_name

        change_column "test_models", "category", :string, null: false

        assert_equal [long_index_name], connection.indexes("test_models").map(&:name)
      end

      def test_remove_column_no_second_parameter_raises_exception
        assert_raise(ArgumentError) { connection.remove_column("funny") }
      end

      def test_removing_column_preserves_custom_primary_key
        connection.create_table "my_table", primary_key: "my_table_id", force: true do |t|
          t.integer "col_one"
          t.string "col_two", limit: 128, null: false
        end

        remove_column "my_table", "col_two"

        assert_equal "my_table_id", connection.primary_key("my_table")

        columns = connection.columns "my_table"
        my_table_id = columns.detect { |c| c.name == "my_table_id" }
        assert_equal "INT64", my_table_id.sql_type
      ensure
        connection.drop_table :my_table rescue nil
      end

      def test_column_with_index
        connection.create_table "my_table", force: true do |t|
          t.string :item_number, index: true
        end

        assert connection.index_exists?("my_table", :item_number, name: :index_my_table_on_item_number)
      ensure
        connection.drop_table :my_table rescue nil
      end

      def test_add_column_without_column_name
        e = assert_raise ArgumentError do
          connection.create_table "my_table", force: true do |t|
            t.timestamp
          end
        end
        assert_equal "Missing column name(s) for timestamp", e.message
      ensure
        connection.drop_table :my_table, if_exists: true
      end
    end
  end
end
