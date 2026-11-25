# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class InformationSchemaTest < TestHelper::MockActiveRecordTest
  attr_reader :info_schema, :tables_schema_result,
    :table_column_option_result, :table_columns_result,
    :indexes_result, :index_columns_result,
    :check_constraints_result, :table_primary_key_result

  def pk_sql
    "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_CATALOG, C.TABLE_SCHEMA, C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME) WHERE TABLE_NAME = @table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name ORDER BY ORDINAL_POSITION"
  end

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
    @table_column_option_result = [
      {
        "COLUMN_NAME" => "name",
        "OPTION_NAME" => "allow_commit_timestamp",
        "OPTION_TYPE" => "BOOL",
        "OPTION_VALUE" => "TRUE"
      }
    ]
    @table_primary_key_result = []
    @table_columns_result = [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "COLUMN_NAME" => "account_id",
        "ORDINAL_POSITION" => 1,
        "GENERATION_EXPRESSION" => nil,
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
        "GENERATION_EXPRESSION" => nil,
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
        "CONSTRAINT_NAME" => "chk_accounts_name",
        "CHECK_CLAUSE" => "name IN ('bob')"
      }
    ]
  end

  def assert_executed_params expected_params_list
    actual_params_list = last_executed_sqls.map { |entry| entry.options[:params].to_h }
    assert_equal expected_params_list, actual_params_list
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
      "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name",
      last_executed_sql
    )
    assert_executed_params [{ "schema_name" => "" }]

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
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name",
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
    )
    assert_executed_params [
      { "schema_name" => "" },
      { "table_name" => "accounts", "schema_name" => "" },
      { "table_name" => "accounts", "schema_name" => "" },
      { "table_name" => "accounts", "schema_name" => "" }
    ]
  end

  def test_list_all_table_with_indexes_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :indexes

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
    assert_executed_params [
      { "schema_name" => "" },
      { "table_name" => "accounts", "schema_name" => "" },
      { "table_name" => "accounts", "schema_name" => "" }
    ]
  end

  def test_list_all_tables_with_full_view
    set_mocked_result tables_schema_result
    info_schema.tables view: :full

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name",
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_get_table
    set_mocked_result tables_schema_result
    table = info_schema.table "accounts"
    assert_instance_of ActiveRecordSpannerAdapter::Table, table

    assert_sql_equal(
      "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME=@table_name",
      last_executed_sql
    )
    assert_executed_params [{ "schema_name" => "", "table_name" => "accounts" }]
  end

  def test_table_with_columns_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :columns

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME=@table_name",
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
    )
  end

  def test_get_table_with_indexes_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :indexes

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME=@table_name",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_get_table_with_full_view
    set_mocked_result tables_schema_result
    info_schema.table "accounts", view: :full

    assert_sql_equal(
      [
        "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME=@table_name",
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
  end

  def test_list_table_columns
    set_mocked_result table_primary_key_result
    set_mocked_result []
    set_mocked_result table_columns_result
    result = info_schema.table_columns "accounts"
    assert_equal result.length, 2

    assert_sql_equal(
      [
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
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
    assert_nil column1.allow_commit_timestamp

    column2 = result[1]
    assert_equal column2.table_name, "accounts"
    assert_equal column2.name, "name"
    assert_equal column2.type, "STRING"
    assert_equal column2.limit, 32
    assert_equal column2.nullable, true
    assert_nil column1.allow_commit_timestamp
  end

  def test_get_table_column_with_options
    set_mocked_result table_primary_key_result
    set_mocked_result table_column_option_result
    set_mocked_result table_columns_result
    result = info_schema.table_columns "accounts"
    assert_equal result.length, 2

    assert_sql_equal(
      [
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
    )

    column1 = result[0]
    assert_equal column1.table_name, "accounts"
    assert_equal column1.name, "account_id"
    assert_equal column1.type, "INT64"
    assert_nil column1.limit
    assert_equal column1.nullable, false
    assert_nil column1.allow_commit_timestamp

    column2 = result[1]
    assert_equal column2.table_name, "accounts"
    assert_equal column2.name, "name"
    assert_equal column2.type, "STRING"
    assert_equal column2.limit, 32
    assert_equal column2.nullable, true
    assert_equal column2.allow_commit_timestamp, true
  end

  def test_get_table_column
    set_mocked_result table_primary_key_result
    set_mocked_result []
    set_mocked_result table_columns_result
    column = info_schema.table_column "accounts", "account_id"
    assert_instance_of ActiveRecordSpannerAdapter::Table::Column, column

    assert_sql_equal(
      [
        pk_sql,
        "SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name AND COLUMN_NAME=@column_name",
        "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION, IS_IDENTITY FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_SCHEMA=@schema_name AND COLUMN_NAME=@column_name ORDER BY ORDINAL_POSITION ASC"
      ],
      last_executed_sqls
    )
    assert_executed_params [
      { "table_name" => "accounts", "schema_name" => "" },
      { "table_name" => "accounts", "schema_name" => "", "column_name" => "account_id" },
      { "table_name" => "accounts", "schema_name" => "", "column_name" => "account_id" }
    ]
  end

  def test_list_table_indexes
    set_mocked_result index_columns_result
    set_mocked_result indexes_result
    result = info_schema.indexes "orders"
    assert_equal result.length, 1

    assert_sql_equal(
      [
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
    assert_executed_params [
      { "table_name" => "orders", "schema_name" => "" },
      { "table_name" => "orders", "schema_name" => "" }
    ]

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
        "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND INDEX_NAME=@index_name ORDER BY ORDINAL_POSITION ASC",
        "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND INDEX_NAME=@index_name AND SPANNER_IS_MANAGED=FALSE"
      ],
      last_executed_sqls
    )
    assert_executed_params [
      { "table_name" => "orders", "schema_name" => "", "index_name" => "index_orders_on_user_id" },
      { "table_name" => "orders", "schema_name" => "", "index_name" => "index_orders_on_user_id" }
    ]

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
      "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME=@table_name AND TABLE_CATALOG = '' AND TABLE_SCHEMA = @schema_name AND INDEX_NAME=@index_name ORDER BY ORDINAL_POSITION ASC",
      last_executed_sql
    )
    assert_executed_params [
      { "table_name" => "orders", "schema_name" => "", "index_name" => "index_orders_on_user_id" }
    ]

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

  def test_unquote_string
    # These test cases come from the official reference
    # https://cloud.google.com/spanner/docs/reference/standard-sql/lexical#string_and_bytes_literals
    [
      # Quoted string
      [%q<"abc">, %q<abc>],
      [%q<"it's">, %q<it's>],
      [%q<'it\\'s'>, %q<it's>],
      [%q<'Title: "Boy"'>, %q<Title: "Boy">],
      # Triple-quoted string
      [%q<"""abc""">, %q<abc>],
      [%q<'''it's'''>, %q<it's>],
      [%q<'''Title:"Boy"'''>, %q<Title:"Boy">],
      [%q<'''two
lines'''>, %q<two
lines>],
      [%q<'''why\\?'''>, %q<why?>],
      # Raw string
      [%q<r"abc+">, %q<abc+>],
      [%q<r"abc+">, %q<abc+>],
      [%q<r'''abc+'''>, %q<abc+>],
      [%q<r"""abc+""">, %q<abc+>],
      [%q<r'f\(abc,
(.*),def\)'>, %q<f\(abc,
(.*),def\)>],
      # Escape sequence
      [%q<"""\\a""">, %Q<\a>],
      [%q<"""\\b""">, %Q<\b>],
      [%q<"""\\f""">, %Q<\f>],
      [%q<"""\\n""">, %Q<\n>],
      [%q<"""\\r""">, %Q<\r>],
      [%q<"""\\t""">, %Q<\t>],
      [%q<"""\\v""">, %Q<\v>],
      [%q<"""\\\\""">, %Q<\\>],
      [%q<"""\\?""">, %q<?>],
      [%q<"""\\`""">, %q<`>],
      [%q<"""a\\142c""">, %q<abc>],
      [%q<"""\\x41B""">, %q<AB>],
      [%q<"""\\u30eb\\u30d3\\u30fc""">, %q<ルビー>],
      [%q<"""\\U0001f436\\U0001f43e""">, %q<🐶🐾>],
    ].each do |quoted, expected|
      assert_equal(expected, info_schema.unquote_string(quoted))
    end
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
      "SELECT tc.TABLE_NAME, tc.CONSTRAINT_NAME, cc.CHECK_CLAUSE FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc INNER JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc ON tc.CONSTRAINT_CATALOG = cc.CONSTRAINT_CATALOG AND tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA AND tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME WHERE tc.TABLE_NAME = @table_name AND tc.CONSTRAINT_SCHEMA = @schema_name AND tc.CONSTRAINT_TYPE = 'CHECK' AND NOT (tc.CONSTRAINT_NAME LIKE 'CK_IS_NOT_NULL_%' AND cc.CHECK_CLAUSE LIKE '%IS NOT NULL')",
      last_executed_sql
    )
    assert_executed_params [{ "table_name" => "accounts", "schema_name" => "" }]

    cc = results.first
    assert_instance_of ActiveRecord::ConnectionAdapters::CheckConstraintDefinition, cc
    assert_equal cc.table_name, "accounts"
    assert_equal cc.name, "chk_accounts_name"
    assert_equal cc.expression, "name IN ('bob')"
  end

  def test_special_characters_and_symbols_are_parameterized
    set_mocked_result []
    info_schema.table :"ac'counts", schema_name: :"my'schema"

    assert_sql_equal(
      "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=@schema_name AND TABLE_NAME=@table_name",
      last_executed_sql
    )
    assert_executed_params [{ "schema_name" => "my'schema", "table_name" => "ac'counts" }]
    assert_equal(
      {
        "schema_name" => Google::Cloud::Spanner::V1::Type.new(code: :STRING),
        "table_name" => Google::Cloud::Spanner::V1::Type.new(code: :STRING)
      },
      last_executed_sql.options[:types]
    )
  end

  def test_foreign_keys_and_index_type_and_nil_schema_name_are_parameterized
    set_mocked_result []
    info_schema.tables schema_name: nil
    assert_executed_params [{ "schema_name" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    set_mocked_result []
    set_mocked_result []
    info_schema.table_columns "orders", schema_name: nil
    assert_executed_params [
      { "table_name" => "orders", "schema_name" => "" },
      { "table_name" => "orders", "schema_name" => "" },
      { "table_name" => "orders", "schema_name" => "" }
    ]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    info_schema.table_primary_keys "orders", schema_name: nil
    assert_executed_params [{ "table_name" => "orders", "schema_name" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    info_schema.index_columns "orders", schema_name: nil
    assert_executed_params [{ "table_name" => "orders", "schema_name" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    info_schema.foreign_keys "orders", from_schema_name: nil
    assert_match(/WHERE FK_TABLE = @table_name\s+AND FK_SCHEMA = @constraint_schema/, last_executed_sql.sql)
    assert_executed_params [{ "table_name" => "orders", "constraint_schema" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    info_schema.check_constraints "orders", schema_name: nil
    assert_executed_params [{ "table_name" => "orders", "schema_name" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    set_mocked_result []
    info_schema.indexes "orders", index_name: "idx_orders", index_type: "INDEX", schema_name: nil
    assert_executed_params [
      { "table_name" => "orders", "schema_name" => "", "index_name" => "idx_orders" },
      { "table_name" => "orders", "schema_name" => "", "index_name" => "idx_orders", "index_type" => "INDEX" }
    ]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    info_schema.table_primary_keys "orders", false, schema_name: "app"
    assert_includes last_executed_sql.sql, "AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN"
    assert_executed_params [{ "table_name" => "orders", "schema_name" => "app" }]
  end

  def test_nil_required_table_name_and_false_optional_filters
    set_mocked_result []
    info_schema.tables(table_name: false)
    refute_includes last_executed_sql.sql, "@table_name"
    assert_executed_params [{ "schema_name" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    set_mocked_result []
    set_mocked_result []
    assert_equal [], info_schema.table_columns(nil, column_name: false)
    last_executed_sqls.each { |executed| refute_includes executed.sql, "@column_name" }
    assert_executed_params [
      { "table_name" => nil, "schema_name" => "" },
      { "table_name" => nil, "schema_name" => "" },
      { "table_name" => nil, "schema_name" => "" }
    ]
    assert_equal(
      {
        "table_name" => Google::Cloud::Spanner::V1::Type.new(code: :STRING),
        "schema_name" => Google::Cloud::Spanner::V1::Type.new(code: :STRING)
      },
      last_executed_sql.options[:types]
    )

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    set_mocked_result []
    assert_equal [], info_schema.indexes(nil, index_name: false, index_type: false)
    last_executed_sqls.each do |executed|
      refute_includes executed.sql, "@index_name"
      refute_includes executed.sql, "@index_type"
    end
    assert_executed_params [
      { "table_name" => nil, "schema_name" => "" },
      { "table_name" => nil, "schema_name" => "" }
    ]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    assert_equal [], info_schema.foreign_keys(nil)
    assert_executed_params [{ "table_name" => nil, "constraint_schema" => "" }]

    MockGoogleSpanner.clear_mocked_executed_sql_and_results
    set_mocked_result []
    assert_equal [], info_schema.check_constraints(nil)
    assert_executed_params [{ "table_name" => nil, "schema_name" => "" }]
  end
end
