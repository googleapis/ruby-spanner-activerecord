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
    class DDLBatchingTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper
      include ActiveSupport::Testing::Stream

      class Box < ActiveRecord::Base
      end

      class CreateBoxMigration < ActiveRecord::Migration::Current
        def change
          create_table("boxes") do |t|
            t.string :name
          end

          add_column :boxes, :length, :integer

          Box.create(name: "Box1", length: 10)
        end
      end

      def setup
        skip_test_table_create!

        super
        ENV["DISABLE_DDL_BATCHING"] = "FALSE"
      end

      def teardown
        super
        ENV["DISABLE_DDL_BATCHING"] = "TRUE"

        [:boxes, :ddl_batch_test].each do |name|
          if connection.table_exists?(name)
            connection.drop_table name
          end
        end
        connection.execute_pending_ddl
      end

      def test_ddl_batching
        information_schema = connection.send :information_schema

        connection.create_table("ddl_batch_test") do |t|
          t.string :name
        end
        connection.add_column :ddl_batch_test, :created_at, :time

        assert_not information_schema.table(:ddl_batch_test)

        connection.execute_pending_ddl

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