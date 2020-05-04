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
    class ColumnPositioningTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def setup
        skip_test_table_create!
        super

        connection.create_table :testing_columns_position, id: false, force: true do |t|
          t.column :first, :integer
          t.column :second, :integer
          t.column :third, :integer
        end
      end

      def teardown
        connection.drop_table :testing_columns_position rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_column_positioning
        assert_equal %w(first second third), connection.columns(:testing_columns_position).map(&:name)
      end

      def test_add_column_with_positioning
        connection.add_column :testing_columns_position, :fourth, :integer
        assert_equal %w(first second third fourth), connection.columns(:testing_columns_position).map(&:name)
      end
    end
  end
end