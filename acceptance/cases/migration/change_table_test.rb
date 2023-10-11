# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class TableTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def setup
        skip_test_table_create!

        super
        @connection = Minitest::Mock.new
      end

      def teardown
        assert @connection.verify
      end

      def with_change_table
        yield ActiveRecord::Base.connection.update_table_definition(:delete_me, @connection)
      end

      def test_remove_references_column_type_with_polymorphic_removes_type
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :taggable], polymorphic: true
          t.remove_references :taggable, polymorphic: true
        end
      end

      def test_references_column_type_with_polymorphic_and_options_null_is_false_adds_table_flag
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :taggable], polymorphic: true, null: false
          t.references :taggable, polymorphic: true, null: false
        end
      end

      def test_remove_references_column_type_with_polymorphic_and_options_null_is_false_removes_table_flag
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :taggable], polymorphic: true, null: false
          t.remove_references :taggable, polymorphic: true, null: false
        end
      end

      def test_references_column_type_with_polymorphic_and_type
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :taggable], polymorphic: true, type: :string
          t.references :taggable, polymorphic: true, type: :string
        end
      end

      def test_remove_references_column_type_with_polymorphic_and_type
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :taggable], polymorphic: true, type: :string
          t.remove_references :taggable, polymorphic: true, type: :string
        end
      end

      def test_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          @connection.expect :add_timestamps, nil, [:delete_me], null: true
          t.timestamps null: true
        end
      end

      def test_remove_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          @connection.expect :remove_timestamps, nil, [:delete_me], null: true
          t.remove_timestamps(null: true)
        end
      end

      def test_primary_key_creates_primary_key_column
        with_change_table do |t|
          @connection.expect :add_column, nil, [:delete_me, :id, :primary_key], primary_key: true, first: true
          t.primary_key :id, first: true
        end
      end

      def test_index_exists
        with_change_table do |t|
          if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3") && ActiveRecord::gem_version <= Gem::Version.create('7.0.4')
            @connection.expect :index_exists?, nil, [:delete_me, :bar, {}]
            t.index_exists?(:bar, {})
          else
            @connection.expect :index_exists?, nil, [:delete_me, :bar]
            t.index_exists?(:bar)
          end
        end
      end

      def test_index_exists_with_options
        with_change_table do |t|
          if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3") && ActiveRecord::gem_version <= Gem::Version.create('7.0.4')
            @connection.expect :index_exists?, nil, [:delete_me, :bar, {unique: true}]
            t.index_exists?(:bar, {unique: true})
          else
            @connection.expect :index_exists?, nil, [:delete_me, :bar], unique: true
            t.index_exists?(:bar, unique: true)
          end
        end
      end

      def test_remove_drops_multiple_columns_when_column_options_are_given
        with_change_table do |t|
          @connection.expect :remove_columns, nil, [:delete_me, :bar, :baz], type: :string, null: false
          t.remove :bar, :baz, type: :string, null: false
        end
      end

      def test_table_name_set
        with_change_table do |t|
          assert_equal :delete_me, t.name
        end
      end
    end
  end
end