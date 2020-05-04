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
        add_column "test_models", "first_name", :string
        add_column "test_models", "last_name", :string
        add_column "test_models", "bio", :text
        add_column "test_models", "age", :integer
        add_column "test_models", "height", :float
        add_column "test_models", "birthday", :datetime
        add_column "test_models", "favorite_day", :date
        add_column "test_models", "moment_of_truth", :datetime
        add_column "test_models", "male", :boolean

        TestModel.create first_name: "bob", last_name: "bobsen",
          bio: "I was born ....", age: 18, height: 1.78,
          birthday: 18.years.ago, favorite_day: 10.days.ago,
          moment_of_truth: "1782-10-10 21:40:18", male: true

        bob = TestModel.first
        assert_equal "bob", bob.first_name
        assert_equal "bobsen", bob.last_name
        assert_equal "I was born ....", bob.bio
        assert_equal 18, bob.age
        assert_equal 1.78, bob.height
        assert_equal true, bob.male?

        assert_equal String, bob.first_name.class
        assert_equal String, bob.last_name.class
        assert_equal String, bob.bio.class
        assert_kind_of Integer, bob.age
        assert_equal Float, bob.height.class
        assert_equal Time, bob.birthday.class
        assert_equal Date, bob.favorite_day.class
        assert_instance_of TrueClass, bob.male?
      end

      def test_out_of_range_limit_should_raise
        assert_raise(ArgumentError) {
          add_column :test_models, :integer_too_big, :integer, limit: 10
        }
      end
    end
  end
end