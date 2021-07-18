# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "bigdecimal"

module ActiveRecord
  class Migration
    class ColumnAttributesTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def test_add_remove_single_field_using_string_arguments
        assert_no_column TestModel, :last_name

        add_column "test_models", "last_name", :string
        assert_column TestModel, :last_name

        remove_column "test_models", "last_name"
        assert_no_column TestModel, :last_name
      end

      def test_add_remove_single_field_using_symbol_arguments
        assert_no_column TestModel, :last_name

        add_column :test_models, :last_name, :string
        assert_column TestModel, :last_name

        remove_column :test_models, :last_name
        assert_no_column TestModel, :last_name
      end

      def test_add_column_without_limit
        add_column :test_models, :description, :string, limit: nil
        TestModel.reset_column_information
        assert_equal "MAX", TestModel.columns_hash["description"].limit
      end

      # We specifically do a manual INSERT here, and then test only the SELECT
      # functionality. This allows us to more easily catch INSERT being broken,
      # but SELECT actually working fine.
      def test_native_float_insert_manual_vs_automatic
        correct_value = "0012345678901234567890.0123456789".to_f

        connection.add_column "test_models", "wealth", :float

        # Do a manual insertion
        connection.transaction {
          connection.execute "insert into test_models (id, wealth) values (#{generate_id}, 12345678901234567890.0123456789)"
        }

        # SELECT
        row = TestModel.first
        assert_kind_of Float, row.wealth

        # If this assert fails, that means the SELECT is broken!
        assert_equal correct_value, row.wealth

        # Reset to old state
        TestModel.delete_all

        # Now use the Rails insertion
        TestModel.create wealth: BigDecimal("12345678901234567890.0123456789")

        # SELECT
        row = TestModel.first
        assert_kind_of Float, row.wealth

        # If these asserts fail, that means the INSERT (create function, or cast to SQL) is broken!
        assert_equal correct_value, row.wealth
      end

      def test_native_types
        connection.ddl_batch do
          add_column "test_models", "first_name", :string
          add_column "test_models", "last_name", :string
          add_column "test_models", "bio", :text
          add_column "test_models", "age", :integer
          add_column "test_models", "height", :float
          add_column "test_models", "birthday", :datetime
          add_column "test_models", "favorite_day", :date
          add_column "test_models", "moment_of_truth", :datetime
          add_column "test_models", "male", :boolean
          add_column "test_models", "weight", :decimal
        end

        TestModel.create first_name: "bob", last_name: "bobsen",
          bio: "I was born ....", age: 18, height: 1.78,
          birthday: 18.years.ago, favorite_day: 10.days.ago,
          moment_of_truth: "1782-10-10 21:40:18", male: true, weight: BigDecimal("75.6", 1)

        bob = TestModel.first
        assert_equal "bob", bob.first_name
        assert_equal "bobsen", bob.last_name
        assert_equal "I was born ....", bob.bio
        assert_equal 18, bob.age
        assert_equal 1.78, bob.height
        assert_equal true, bob.male?
        assert_equal BigDecimal("75.6", 1), bob.weight

        assert_equal String, bob.first_name.class
        assert_equal String, bob.last_name.class
        assert_equal String, bob.bio.class
        assert_kind_of Integer, bob.age
        assert_equal Float, bob.height.class
        assert_equal Time, bob.birthday.class
        assert_equal Date, bob.favorite_day.class
        assert_instance_of TrueClass, bob.male?
        assert_equal BigDecimal, bob.weight.class
      end

      def test_add_column_and_ignore_limit
        add_column :test_models, :integer_ignore_limit, :integer, limit: 10
        assert_column TestModel, :integer_ignore_limit
      end
    end
  end
end