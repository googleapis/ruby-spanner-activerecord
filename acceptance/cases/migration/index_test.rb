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
    class IndexTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      attr_reader :table_name

      def setup
        skip_test_table_create!
        super

        @table_name = :testings

        connection.create_table table_name do |t|
          t.column :foo, :string, limit: 100
          t.column :bar, :string, limit: 100

          t.string :first_name
          t.string :last_name, limit: 100
          t.string :key,       limit: 100
          t.boolean :administrator
        end
      end

      def teardown
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_rename_index
        connection.add_index(table_name, [:foo], name: "old_idx")
        connection.rename_index(table_name, "old_idx", "new_idx")

        assert_not connection.index_name_exists?(table_name, "old_idx")
        assert connection.index_name_exists?(table_name, "new_idx")
      end

      def test_rename_index_too_long
        too_long_index_name = good_index_name + "x"
        connection.add_index(table_name, [:foo], name: "old_idx")
        e = assert_raises(ArgumentError) {
          connection.rename_index(table_name, "old_idx", too_long_index_name)
        }
        assert_match(/too long; the limit is #{connection.allowed_index_name_length} characters/, e.message)

        assert connection.index_name_exists?(table_name, "old_idx")
      end

      def test_remove_nonexistent_index
        assert_raise(ArgumentError) { connection.remove_index(table_name, "no_such_index") }
      end

      def test_add_index_works_with_long_index_names
        connection.add_index(table_name, "foo", name: good_index_name)

        assert connection.index_name_exists?(table_name, good_index_name)
        connection.remove_index(table_name, name: good_index_name)
      end

      def test_add_index_does_not_accept_too_long_index_names
        too_long_index_name = good_index_name + "x"

        e = assert_raises(ArgumentError) {
          connection.add_index(table_name, "foo", name: too_long_index_name)
        }
        assert_match(/too long; the limit is #{connection.allowed_index_name_length} characters/, e.message)

        assert_not connection.index_name_exists?(table_name, too_long_index_name)
        connection.add_index(table_name, "foo", name: good_index_name)
      end

      def test_internal_index_with_name_matching_database_limit
        good_index_name = "x" * connection.index_name_length
        connection.add_index(table_name, "foo", name: good_index_name)

        assert connection.index_name_exists?(table_name, good_index_name)
        connection.remove_index(table_name, name: good_index_name)
      end

      def test_index_symbol_names
        connection.add_index table_name, :foo, name: :symbol_index_name
        assert connection.index_exists?(table_name, :foo, name: :symbol_index_name)

        connection.remove_index table_name, name: :symbol_index_name
        assert_not connection.index_exists?(table_name, :foo, name: :symbol_index_name)
      end

      def test_index_exists
        connection.add_index :testings, :foo

        assert connection.index_exists?(:testings, :foo)
        assert_not connection.index_exists?(:testings, :bar)
      end

      def test_index_exists_on_multiple_columns
        connection.add_index :testings, [:foo, :bar]

        assert connection.index_exists?(:testings, [:foo, :bar])
      end

      def test_index_exists_with_custom_name_checks_columns
        connection.add_index :testings, [:foo, :bar], name: "my_index"
        assert connection.index_exists?(:testings, [:foo, :bar], name: "my_index")
        assert_not connection.index_exists?(:testings, [:foo], name: "my_index")
      end

      def test_valid_index_options
        assert_raise ArgumentError do
          connection.add_index :testings, :foo, unqiue: true
        end
      end

      def test_unique_index_exists
        connection.add_index :testings, :foo, unique: true

        assert connection.index_exists?(:testings, :foo, unique: true)
      end

      def test_order_index_exists
        connection.add_index :testings, :foo, order: { foo: :desc }

        assert connection.index_exists?(:testings, :foo)

        index = connection.indexes(:testings).first
        assert_equal({ foo: :desc }, index.orders)
      end

      def test_named_index_exists
        connection.add_index :testings, :foo, name: "custom_index_name"

        assert connection.index_exists?(:testings, :foo)
        assert connection.index_exists?(:testings, :foo, name: "custom_index_name")
        assert_not connection.index_exists?(:testings, :foo, name: "other_index_name")
      end

      def test_remove_named_index
        connection.add_index :testings, :foo, name: "index_testings_on_custom_index_name"

        assert connection.index_exists?(:testings, :foo)

        assert_raise(ArgumentError) { connection.remove_index(:testings, "custom_index_name") }

        connection.remove_index :testings, :foo
        assert_not connection.index_exists?(:testings, :foo)
      end

      def test_add_index
        connection.add_index("testings", "last_name")
        connection.remove_index("testings", "last_name")

        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", column: ["last_name", "first_name"])

        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", name: :index_testings_on_last_name_and_first_name)
        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", "last_name_and_first_name")

        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", ["last_name", "first_name"])

        connection.add_index("testings", "key", unique: true)
        connection.remove_index("testings", "key")

        connection.add_index("testings", ["key"], name: "key_idx", unique: true)
        connection.remove_index("testings", name: "key_idx")

        connection.add_index("testings", %w(last_name first_name administrator), name: "named_admin")
        connection.remove_index("testings", name: "named_admin")

        connection.add_index("testings", ["last_name"], order: { last_name: :desc })
        connection.remove_index("testings", ["last_name"])
        connection.add_index("testings", ["last_name", "first_name"], order: { last_name: :desc })
        connection.remove_index("testings", ["last_name", "first_name"])
        connection.add_index("testings", ["last_name", "first_name"], order: { last_name: :desc, first_name: :asc })
        connection.remove_index("testings", ["last_name", "first_name"])
        connection.add_index("testings", ["last_name", "first_name"], order: :desc)
        connection.remove_index("testings", ["last_name", "first_name"])
      end

      private
      def good_index_name
        "x" * connection.allowed_index_name_length
      end
    end
  end
end
