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
    class ReferencesIndexTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      attr_reader :table_name

      def setup
        skip_test_table_create!
        super

        @table_name = :testings
      end

      def teardown
        connection.drop_table :testings rescue nil
      end

      def test_creates_index
        connection.create_table table_name do |t|
          t.references :foo, index: true
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_index_by_default_even_if_index_option_is_not_passed
        connection.create_table table_name do |t|
          t.references :foo
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_does_not_create_index_explicit
        connection.create_table table_name do |t|
          t.references :foo, index: false
        end

        assert_not connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_index_with_options
        connection.create_table table_name do |t|
          t.references :foo, index: { name: :index_testings_on_yo_momma }
          t.references :bar, index: { unique: true }
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_yo_momma)
        assert connection.index_exists?(table_name, :bar_id, name: :index_testings_on_bar_id, unique: true)
      end

      def test_creates_polymorphic_index
        connection.create_table table_name do |t|
          t.references :foo, polymorphic: true, index: true
        end

        assert connection.index_exists?(table_name, [:foo_type, :foo_id], name: :index_testings_on_foo_type_and_foo_id)
      end

      def test_creates_index_for_existing_table
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, index: true
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_index_for_existing_table_even_if_index_option_is_not_passed
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_does_not_create_index_for_existing_table_explicit
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, index: false
        end

        assert_not connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_polymorphic_index_for_existing_table
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, polymorphic: true, index: true
        end

        assert connection.index_exists?(table_name, [:foo_type, :foo_id], name: :index_testings_on_foo_type_and_foo_id)
      end
    end
  end
end
