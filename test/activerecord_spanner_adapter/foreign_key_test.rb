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

class InformationSchemaForeignKeyTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :column_name, :contraint_name,
    :ref_table_name, :ref_column_name

  def setup
    @table_name = "test-table"
    @column_name = "test-column"
    @contraint_name = "test-contraint"
    @ref_table_name = "test-ref-table"
    @ref_column_name = "test-ref-column"
  end

  def test_create_instance_of_foreign_key
    fk = ActiveRecordSpannerAdapter::ForeignKey.new(
      table_name, contraint_name, column_name,
      ref_table_name, ref_column_name
    )

    assert_equal fk.table_name, table_name
    assert_equal fk.columns, [column_name]
    assert_equal fk.name, contraint_name
    assert_equal fk.ref_table, ref_table_name
    assert_equal fk.ref_columns, [ref_column_name]
  end
end
