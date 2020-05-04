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

class InformationSchemaTableTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :parent_table_name

  def setup
    super
    @table_name = "test-table"
    @parent_table_name = "test-parent-table"
  end

  def test_create_a_instance_of_table
    column1 = new_table_column(
      table_name: table_name, column_name: "id", type: "STRING", limit: 36
    )
    column1.primary_key = true
    column2 = new_table_column(
      table_name: table_name, column_name: "DESC", type: "STRING", limit: "MAX"
    )

    table = ActiveRecordSpannerAdapter::Table.new(
      table_name,
      parent_table: parent_table_name,
      on_delete: "CASCADE",
      schema_name: "",
      catalog: ""
    )

    table.columns = [column1, column2]

    assert_equal table.name, table_name
    assert_equal table.parent_table, parent_table_name
    assert_equal table.on_delete, "CASCADE"
    assert_equal table.cascade?, true
    assert_empty table.catalog
    assert_empty table.schema_name
    assert_equal table.columns.length, 2
    assert_equal table.primary_keys, ["id"]
  end
end
