# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class DDLBatchingTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper
      include ActiveSupport::Testing::Stream

      class Box < ActiveRecord::Base
      end

      class CreateBoxMigration < ActiveRecord::Migration::Current
        def change
          connection.ddl_batch do
            create_table("boxes") do |t|
              t.string :name
            end

            add_column :boxes, :length, :integer
          end

          Box.create(name: "Box1", length: 10)
        end
      end

      def setup
        skip_test_table_create!

        super
      end

      def teardown
        super

        connection.ddl_batch do
          [:boxes, :ddl_batch_test].each do |name|
            if connection.table_exists?(name)
              connection.drop_table name
            end
          end
        end
      end

      def test_ddl_batching
        information_schema = connection.send :information_schema

        connection.ddl_batch do
          connection.create_table("ddl_batch_test") do |t|
            t.string :name
          end
          connection.add_column :ddl_batch_test, :created_at, :time

          assert_not information_schema.table(:ddl_batch_test)
        end

        assert information_schema.table(:ddl_batch_test)
      end

      def test_ddl_batching_with_dml_statement
        migration = CreateBoxMigration.new
        silence_stream($stdout) { migration.migrate(:up) }

        assert connection.table_exists?(:boxes)
        assert connection.column_exists?(:boxes, :length, :integer)

        assert_equal 1, Box.count
        box = Box.first
        assert_equal 10, box.length
      end
    end
  end
end