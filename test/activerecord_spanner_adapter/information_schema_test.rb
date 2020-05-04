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

class InformationSchemaTest < TestHelper::MockActiveRecordTest
  attr_reader :info_schema, :tables_schema_result,
    :table_columns_result, :indexes_result,
    :index_columns_result

  def setup
    super
    @info_schema = ActiveRecordSpannerAdapter::InformationSchema.new connection
    @tables_schema_result = [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "PARENT_TABLE_NAME" => nil,
        "ON_DELETE_ACTION" => nil,
        "SPANNER_STATE" => "COMMITTED"
      }
    ]
    @table_columns_result = [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "COLUMN_NAME" => "account_id",
        "ORDINAL_POSITION" => 1,
        "COLUMN_DEFAULT" => nil,
        "DATA_TYPE" => nil,
        "IS_NULLABLE" => "NO",
        "SPANNER_TYPE" => "INT64"
      },
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "COLUMN_NAME" => "name",
        "ORDINAL_POSITION" => 2,
        "COLUMN_DEFAULT" => nil,
        "DATA_TYPE" => nil,
        "IS_NULLABLE" => "YES",
        "SPANNER_TYPE" => "STRING(32)"
      }
    ]

    @indexes_result = [
      {
        "TABLE_CATALOG" =>"",
        "TABLE_SCHEMA" =>"",
        "TABLE_NAME" => "orders",
        "INDEX_NAME" => "index_orders_on_user_id",
        "INDEX_TYPE" => "INDEX",
        "PARENT_TABLE_NAME" => "",
        "IS_UNIQUE" => false,
        "IS_NULL_FILTERED" => false,
        "INDEX_STATE" => "READ_WRITE",
        "SPANNER_IS_MANAGED" => false
      }
    ]
    @index_columns_result = [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "orders",
        "INDEX_NAME" => "index_orders_on_user_id",
        "INDEX_TYPE" => "INDEX",
        "COLUMN_NAME" => "user_id",
        "ORDINAL_POSITION" => 1,
        "COLUMN_ORDERING" => "ASC",
        "IS_NULLABLE" => "YES",
        "SPANNER_TYPE" => "INT64"
      }
    ]
  end

  def test_create_an_instance
    info_schema = ActiveRecordSpannerAdapter::InformationSchema.new connection
    assert_instance_of ActiveRecordSpannerAdapter::InformationSchema, info_schema
  end

  def test_list_all_tables
    set_mocked_result tables_schema_result
    result = info_schema.tables
    assert_equal result.length, 1

    assert_sql_equal(
      last_executed_sql,
      "SELECT * FROM information_schema.tables WHERE table_schema=''"
    )

    result.each do |table|
      assert_instance_of ActiveRecordSpannerAdapter::Table, table
    end

    table = result.first
    assert_equal table.name,"accounts"
  end

  def test_list_all_tables_with_columns_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :columns

    assert_sql_equal(
      last_executed_sqls,
      [
        "SELECT * FROM information_schema.tables WHERE table_schema=''",
        "SELECT * FROM information_schema.columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC"
      ]
    )
  end

  def test_list_all_table_with_indexes_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :indexes

    assert_sql_equal(
      last_executed_sqls,
      [
        "SELECT * FROM information_schema.tables WHERE table_schema=''",
        "SELECT * FROM information_schema.index_columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT * FROM information_schema.indexes WHERE table_name='accounts' AND spanner_is_managed=false"
      ]
    )
  end

  def test_list_all_tables_with_full_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :full

    assert_sql_equal(
      last_executed_sqls,
      [
        "SELECT * FROM information_schema.tables WHERE table_schema=''",
        "SELECT * FROM information_schema.columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT * FROM information_schema.index_columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT * FROM information_schema.indexes WHERE table_name='accounts' AND spanner_is_managed=false"
      ]
    )
  end

  def test_get_table
    set_mocked_result tables_schema_result
    table = info_schema.table "accounts"
    assert_instance_of ActiveRecordSpannerAdapter::Table, table

    assert_sql_equal(
      last_executed_sql,
      "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'"
    )
  end

  def test_table_with_columns_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :columns

    assert_sql_equal(
      last_executed_sqls,
      "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
      "SELECT * FROM information_schema.columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC"
    )
  end

  def test_get_table_with_indexes_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :indexes

    assert_sql_equal(
      last_executed_sqls,
      [
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
        "SELECT * FROM information_schema.index_columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT * FROM information_schema.indexes WHERE table_name='accounts' AND spanner_is_managed=false"
      ]
    )
  end

  def test_get_table_with_full_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :full

    assert_sql_equal(
      last_executed_sqls,
      [
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
        "SELECT * FROM information_schema.columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT * FROM information_schema.index_columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT * FROM information_schema.indexes WHERE table_name='accounts' AND spanner_is_managed=false"
      ]
    )
  end

  def test_list_table_columns
    set_mocked_result table_columns_result
    result = info_schema.table_columns "accounts"
    assert_equal result.length, 2

    assert_sql_equal(
      last_executed_sql,
      "SELECT * FROM information_schema.columns WHERE table_name='accounts' ORDER BY ORDINAL_POSITION ASC"
    )

    result.each do |column|
      assert_instance_of ActiveRecordSpannerAdapter::Table::Column, column
    end

    column1 = result[0]
    assert_equal column1.table_name, "accounts"
    assert_equal column1.name, "account_id"
    assert_equal column1.type, "INT64"
    assert_nil column1.limit
    assert_equal column1.nullable, false

    column2 = result[1]
    assert_equal column2.table_name, "accounts"
    assert_equal column2.name, "name"
    assert_equal column2.type, "STRING"
    assert_equal column2.limit, 32
    assert_equal column2.nullable, true
  end

  def test_get_table_column
    set_mocked_result table_columns_result
    column = info_schema.table_column "accounts", "account_id"
    assert_instance_of ActiveRecordSpannerAdapter::Table::Column, column

    assert_sql_equal(
      last_executed_sql,
      "SELECT * FROM information_schema.columns WHERE table_name='accounts' AND column_name='account_id' ORDER BY ORDINAL_POSITION ASC"
    )
  end

  def test_list_table_indexes
    set_mocked_result index_columns_result
    set_mocked_result indexes_result
    result = info_schema.indexes "orders"
    assert_equal result.length, 1

    assert_sql_equal(
      last_executed_sqls,
      "SELECT * FROM information_schema.index_columns WHERE table_name='orders' ORDER BY ORDINAL_POSITION ASC",
      "SELECT * FROM information_schema.indexes WHERE table_name='orders' AND spanner_is_managed=false"
    )

    result.each do |index|
      assert_instance_of ActiveRecordSpannerAdapter::Index, index
    end

    index = result[0]
    assert_equal index.table, "orders"
    assert_equal index.name, "index_orders_on_user_id"
    assert_equal index.unique, false
    assert_equal index.null_filtered, false
    assert_empty index.storing
    assert_nil index.interleve_in
    assert_equal index.columns.length, 1
    index.columns.each do |column|
      assert_instance_of ActiveRecordSpannerAdapter::Index::Column, column
    end

    assert_equal index.columns.first.name, "user_id"
  end

  def test_get_an_index
    set_mocked_result index_columns_result
    set_mocked_result indexes_result
    index = info_schema.index "orders", "index_orders_on_user_id"
    assert_instance_of ActiveRecordSpannerAdapter::Index, index

    assert_sql_equal(
      last_executed_sqls,
      "SELECT * FROM information_schema.index_columns WHERE table_name='orders' AND index_name='index_orders_on_user_id' ORDER BY ORDINAL_POSITION ASC",
      "SELECT * FROM information_schema.indexes WHERE table_name='orders' AND index_name='index_orders_on_user_id' AND spanner_is_managed=false"
    )

    assert_equal index.table, "orders"
    assert_equal index.name, "index_orders_on_user_id"
    assert_equal index.unique, false
    assert_equal index.null_filtered, false
    assert_nil index.interleve_in
    assert_empty index.storing
    assert_equal index.columns.length, 1
    index.columns.each do |column|
      assert_instance_of ActiveRecordSpannerAdapter::Index::Column, column
    end

    assert_equal index.columns.first.name, "user_id"
  end

  def test_list_index_columns
    set_mocked_result index_columns_result
    result = info_schema.index_columns "orders", index_name: "index_orders_on_user_id"
    assert_equal result.length, 1

    assert_sql_equal(
      last_executed_sqls,
      "SELECT * FROM information_schema.index_columns WHERE table_name='orders' AND index_name='index_orders_on_user_id' ORDER BY ORDINAL_POSITION ASC"
    )

    column = result.first
    assert_equal column.table_name, "orders"
    assert_equal column.index_name, "index_orders_on_user_id"
    assert_equal column.name, "user_id"
    assert_equal column.order, "ASC"
  end

  def test_list_indexs_by_columns
    set_mocked_result index_columns_result
    set_mocked_result indexes_result
    result = info_schema.indexes_by_columns "orders", ["user_id"]
    assert_equal result.length, 1

    index = result.first
    assert_equal index.name, "index_orders_on_user_id"
    assert_equal index.columns.any?{ |c| c.name == "user_id"}, true
  end
end
