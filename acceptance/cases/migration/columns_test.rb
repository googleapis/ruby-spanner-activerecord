# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ColumnsTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def test_rename_column
        connection.ddl_batch do
          add_column "test_models", :hat_name, :string
        end
        assert_column TestModel, :hat_name

        rename_column "test_models", :hat_name, :cap_name
        assert_column TestModel, :cap_name
      end

      def test_change_column_default_value
        error = assert_raise ActiveRecordSpannerAdapter::NotSupportedError do
          change_column_default "test_models", :hat_name, "hat"
        end

        assert_equal "change column with default value not supported.", error.message
      end

      def test_remove_column_with_index
        connection.ddl_batch do
          add_column "test_models", :hat_name, :string
          add_index :test_models, :hat_name
        end

        assert_equal 1, connection.indexes("test_models").size
        connection.ddl_batch do
          remove_column "test_models", "hat_name"
        end
        assert_equal 0, connection.indexes("test_models").size
      end

      def test_remove_column_with_multi_column_index
        connection.ddl_batch do
          add_column "test_models", :hat_size, :integer
          add_column "test_models", :hat_style, :string, limit: 100
          add_index "test_models", ["hat_style", "hat_size"], unique: true
        end

        assert_equal 1, connection.indexes("test_models").size
        connection.ddl_batch do
          remove_column "test_models", "hat_size"
        end

        assert_equal [], connection.indexes("test_models").map(&:name)
      end

      def test_change_type_of_not_null_column
        connection.ddl_batch do
          change_column "test_models", "updated_at", :datetime, null: false
          change_column "test_models", "updated_at", :datetime, null: false
        end

        TestModel.reset_column_information
        assert_equal false, TestModel.columns_hash["updated_at"].null
      ensure
        connection.ddl_batch do
          change_column "test_models", "updated_at", :datetime, null: true
        end
      end

      def test_change_column_nullability
        connection.ddl_batch do
          add_column "test_models", "funny", :boolean
        end
        assert TestModel.columns_hash["funny"].null, "Column 'funny' must initially allow nulls"

        connection.ddl_batch do
          change_column "test_models", "funny", :boolean, null: false
        end

        TestModel.reset_column_information
        assert_not TestModel.columns_hash["funny"].null, "Column 'funny' must *not* allow nulls at this point"

        connection.ddl_batch do
          change_column "test_models", "funny", :boolean, null: true
        end
        TestModel.reset_column_information
        assert TestModel.columns_hash["funny"].null, "Column 'funny' must allow nulls again at this point"
      end

      def test_change_column
        # Only string and binary allows to change types
        connection.ddl_batch do
          add_column "test_models", "name", :string
        end

        old_columns = connection.columns TestModel.table_name

        assert old_columns.find { |c| c.name == "name" && c.type == :string }

        connection.ddl_batch do
          change_column "test_models", "name", :binary
        end

        new_columns = connection.columns TestModel.table_name

        assert_not new_columns.find { |c| c.name == "name" && c.type == :string }
        assert new_columns.find { |c| c.name == "name" && c.type == :binary }
      end

      def test_change_column_with_custom_index_name
        connection.ddl_batch do
          add_column :test_models, :category, :string
          add_index :test_models, :category, name: "test_models_categories_idx", order: { category: :desc}
        end

        assert_equal ["test_models_categories_idx"], connection.indexes("test_models").map(&:name)
        connection.ddl_batch do
          change_column "test_models", "category", :string, null: false
        end

        assert column_exists?(:test_models, :category, :string, null: false)
        indexes = connection.indexes("test_models")
        assert_equal ["test_models_categories_idx"], indexes.map(&:name)
        assert_equal({ category: :desc }, indexes.first.orders)
      end

      def test_change_column_with_long_index_name
        table_name_prefix = "test_models_"
        long_index_name = table_name_prefix + ("x" * (connection.index_name_length - table_name_prefix.length))
        connection.ddl_batch do
          add_column "test_models", "category", :string
          add_index :test_models, :category, name: long_index_name
        end

        connection.ddl_batch do
          change_column "test_models", "category", :string, null: false
        end

        assert_equal [long_index_name], connection.indexes("test_models").map(&:name)
      end

      def test_remove_column_no_second_parameter_raises_exception
        assert_raise(ArgumentError) { connection.remove_column("funny") }
      end

      def test_removing_column_preserves_custom_primary_key
        connection.ddl_batch do
          connection.create_table "my_table", primary_key: "my_table_id", force: true do |t|
            t.integer "col_one"
            t.string "col_two", limit: 128, null: false
          end
        end

        connection.ddl_batch do
          remove_column "my_table", "col_two"
        end

        assert_equal "my_table_id", connection.primary_key("my_table")

        columns = connection.columns "my_table"
        my_table_id = columns.detect { |c| c.name == "my_table_id" }
        assert_equal "INT64", my_table_id.sql_type
      ensure
        connection.ddl_batch do
          connection.drop_table :my_table rescue nil
        end
      end

      def test_column_with_index
        connection.ddl_batch do
          connection.create_table "my_table", force: true do |t|
            t.string :item_number, index: true
          end
        end

        assert connection.index_exists?("my_table", :item_number, name: :index_my_table_on_item_number)
      ensure
        connection.ddl_batch do
          connection.drop_table :my_table rescue nil
        end
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
