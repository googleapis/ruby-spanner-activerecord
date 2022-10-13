# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class InformationSchemaTest < TestHelper::MockActiveRecordTest
  attr_reader :info_schema, :tables_schema_result,
    :table_columns_result, :indexes_result,
    :index_columns_result,
    :check_constraints_result

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
    @check_constraints_result = [
      {
        "TABLE_NAME" => "accounts",
        "CONSTRAINT_NAME" => "chk_rails_accounts_name",
        "CHECK_CLAUSE" => "name IN ('bob')"
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
      "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''",
      last_executed_sql
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
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='accounts' ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
    )
  end

  def test_list_all_table_with_indexes_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :indexes

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_list_all_tables_with_full_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :full

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_get_table
    set_mocked_result tables_schema_result
    table = info_schema.table "accounts"
    assert_instance_of ActiveRecordSpannerAdapter::Table, table

    assert_sql_equal(
      "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='accounts'",
      last_executed_sql
    )
  end

  def test_table_with_columns_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :columns

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='accounts'",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='accounts' ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
    )
  end

  def test_get_table_with_indexes_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :indexes

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='accounts'",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_get_table_with_full_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :full

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='accounts'",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='accounts' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='accounts' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_list_table_columns
    set_mocked_result table_columns_result
    result = info_schema.table_columns "accounts"
    assert_equal result.length, 2

    assert_sql_equal(
      "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='accounts' ORDER BY ORDINAL_POSITION ASC",
      last_executed_sql
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
      "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='accounts' AND COLUMN_NAME='account_id' ORDER BY ORDINAL_POSITION ASC",
      last_executed_sql
    )
  end

  def test_list_table_indexes
    set_mocked_result index_columns_result
    set_mocked_result indexes_result
    result = info_schema.indexes "orders"
    assert_equal result.length, 1

    assert_sql_equal(
      [
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='orders' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='orders' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
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
    assert_nil index.interleave_in
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
      [
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='orders' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_orders_on_user_id' ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='orders' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_orders_on_user_id' AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )

    assert_equal index.table, "orders"
    assert_equal index.name, "index_orders_on_user_id"
    assert_equal index.unique, false
    assert_equal index.null_filtered, false
    assert_nil index.interleave_in
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
      "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='orders' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_orders_on_user_id' ORDER BY ORDINAL_POSITION ASC",
      last_executed_sqls
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

  def test_empty_check_contraints
    set_mocked_result []
    results = info_schema.check_constraints "accounts"
    assert_empty results
  end

  def test_check_constraints
    set_mocked_result check_constraints_result
    results = info_schema.check_constraints "accounts"
    assert_equal results.length, 1

    assert_sql_equal(
      "SELECT tc.TABLE_NAME, tc.CONSTRAINT_NAME, cc.CHECK_CLAUSE FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc INNER JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME WHERE tc.TABLE_NAME = 'accounts' AND tc.CONSTRAINT_TYPE = 'CHECK' AND tc.CONSTRAINT_NAME LIKE 'chk_rails_%'",
      last_executed_sql
    )

    cc = results.first
    assert_instance_of ActiveRecord::ConnectionAdapters::CheckConstraintDefinition, cc
    assert_equal cc.table_name, "accounts"
    assert_equal cc.name, "chk_rails_accounts_name"
    assert_equal cc.expression, "name IN ('bob')"
  end
end
