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

require "test_helper"

class InformationSchemaTableColumnTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :column_name

  def setup
    super
    @table_name = "test-table"
    @column_name = "test-column"
  end

  def test_create_instance_of_table_column
    column = ActiveRecordSpannerAdapter::Table::Column.new(
      table_name, column_name, "STRING",
      limit: 255, ordinal_position: 1, nullable: true,
      allow_commit_timestamp: true,
    )

    assert_equal column.name, column_name
    assert_equal column.table_name, table_name
    assert_equal column.type, "STRING"
    assert_equal column.limit, 255
    assert_equal column.ordinal_position, 1
    assert_equal column.nullable, true
    assert_equal column.allow_commit_timestamp, true
    assert_equal column.primary_key, false
  end

  def test_set_default_nullable_for_non_primary_key_column
    column = new_table_column
    column.primary_key = false
    assert_equal column.primary_key, false
    assert_equal column.nullable, true
  end

  def test_set_default_not_nullable_for_primary_key_column
    column = new_table_column
    column.primary_key = true
    assert_equal column.primary_key, true
    assert_equal column.nullable, false
  end

  def test_spanner_type_for_integer
    column = new_table_column type: "INT64"
    assert_equal column.spanner_type, "INT64"

    column = new_table_column type: "INT64", limit: 10000
    assert_equal column.spanner_type, "INT64"
  end

  def test_spanner_type_for_float
    column = new_table_column type: "FLOAT64"
    assert_equal column.spanner_type, "FLOAT64"

    column = new_table_column type: "FLOAT64", limit: 10000
    assert_equal column.spanner_type, "FLOAT64"
  end

  def test_spanner_type_for_boolean
    column = new_table_column type: "BOOL"
    assert_equal column.spanner_type, "BOOL"

    column = new_table_column type: "BOOL", limit: 1
    assert_equal column.spanner_type, "BOOL"
  end

  def test_spanner_type_for_string
    column = new_table_column type: "STRING"
    assert_equal column.spanner_type, "STRING(MAX)"

    column = new_table_column type: "STRING", limit: 1024
    assert_equal column.spanner_type, "STRING(1024)"
  end

  def test_spanner_type_for_bytes
    column = new_table_column type: "BYTES"
    assert_equal column.spanner_type, "BYTES(MAX)"

    column = new_table_column type: "BYTES", limit: 1024
    assert_equal column.spanner_type, "BYTES(1024)"
  end

  def test_spanner_type_for_date
    column = new_table_column type: "DATE"
    assert_equal column.spanner_type, "DATE"

    column = new_table_column type: "DATE", limit: 1024
    assert_equal column.spanner_type, "DATE"
  end

  def test_spanner_type_for_timestamp
    column = new_table_column type: "TIMESTAMP"
    assert_equal column.spanner_type, "TIMESTAMP"

    column = new_table_column type: "TIMESTAMP", limit: 1024
    assert_equal column.spanner_type, "TIMESTAMP"
  end
end
