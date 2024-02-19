# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"
require_relative "models/singer"
require_relative "models/album"

require "securerandom"

module MockServerTests
  StructType = Google::Cloud::Spanner::V1::StructType
  Field = Google::Cloud::Spanner::V1::StructType::Field
  ResultSetMetadata = Google::Cloud::Spanner::V1::ResultSetMetadata
  ResultSet = Google::Cloud::Spanner::V1::ResultSet
  ListValue = Google::Protobuf::ListValue
  Value = Google::Protobuf::Value
  ResultSetStats = Google::Cloud::Spanner::V1::ResultSetStats

  TypeCode = Google::Cloud::Spanner::V1::TypeCode
  Type = Google::Cloud::Spanner::V1::Type

  def self.create_id_returning_result_set id, update_count
    col_id = Field.new name: "id", type: Type.new(code: TypeCode::INT64)
    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_id
    result_set = ResultSet.new metadata: metadata
    row = ListValue.new
    row.values.push Value.new(string_value: id.to_s)
    result_set.rows.push row
    result_set.stats = ResultSetStats.new
    result_set.stats.row_count_exact = update_count

    StatementResult.new result_set
  end

  def self.create_random_singers_result(row_count, lock_version = false)
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson]
    col_id = Field.new name: "id", type: Type.new(code: TypeCode::INT64)
    col_first_name = Field.new name: "first_name", type: Type.new(code: TypeCode::STRING)
    col_last_name = Field.new name: "last_name", type: Type.new(code: TypeCode::STRING)
    col_last_performance = Field.new name: "last_performance", type: Type.new(code: TypeCode::TIMESTAMP)
    col_picture = Field.new name: "picture", type: Type.new(code: TypeCode::BYTES)
    col_revenues = Field.new name: "revenues", type: Type.new(code: TypeCode::NUMERIC)
    col_lock_version = Field.new name: "lock_version", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_id, col_first_name, col_last_name, col_last_performance, col_picture, col_revenues
    metadata.row_type.fields.push col_lock_version if lock_version
    result_set = ResultSet.new metadata: metadata

    (1..row_count).each { |_|
      row = ListValue.new
      row.values.push(
        Value.new(string_value: SecureRandom.random_number(1000000).to_s),
        Value.new(string_value: first_names.sample),
        Value.new(string_value: last_names.sample),
        Value.new(string_value: StatementResult.random_timestamp_string),
        Value.new(string_value: Base64.encode64(SecureRandom.alphanumeric(SecureRandom.random_number(10..200)))),
        Value.new(string_value: SecureRandom.random_number(1000.0..1000000.0).to_s),
      )
      row.values.push Value.new(string_value: lock_version.to_s) if lock_version
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.create_random_albums_result(row_count)
    adjectives = ["daily", "happy", "blue", "generous", "cooked", "bad", "open"]
    nouns = ["windows", "potatoes", "bank", "street", "tree", "glass", "bottle"]

    col_id = Field.new name: "id", type: Type.new(code: TypeCode::INT64)
    col_title = Field.new name: "title", type: Type.new(code: TypeCode::STRING)
    col_singer_id = Field.new name: "singer_id", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_id, col_title, col_singer_id
    result_set = ResultSet.new metadata: metadata

    (1..row_count).each { |_|
      row = ListValue.new
      row.values.push(
        Value.new(string_value: SecureRandom.random_number(1000000).to_s),
        Value.new(string_value: "#{adjectives.sample} #{nouns.sample}"),
        Value.new(string_value: SecureRandom.random_number(1000000).to_s)
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.primary_key_columns_sql table_name, parent_keys: false
    sql = +"WITH TABLE_PK_COLS AS ( SELECT C.TABLE_CATALOG, C.TABLE_SCHEMA, C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, "
    sql << "C.COLUMN_ORDERING, C.ORDINAL_POSITION "
    sql << "FROM INFORMATION_SCHEMA.INDEX_COLUMNS C "
    sql << "WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') "
    sql << "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION "
    sql << "FROM TABLE_PK_COLS "
    sql << "INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME) "
    sql << "WHERE TABLE_NAME = '%<table_name>s' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' "
    unless parent_keys
      sql << "AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   "
      sql << "SELECT COLUMN_NAME   FROM TABLE_PK_COLS   "
      sql << "WHERE TABLE_CATALOG = T.TABLE_CATALOG   AND TABLE_SCHEMA=T.TABLE_SCHEMA   AND TABLE_NAME = T.PARENT_TABLE_NAME )) "
    end
    sql << "ORDER BY ORDINAL_POSITION"
    sql % { table_name: table_name}
  end

  def self.table_columns_sql table_name, column_name: nil
    sql = +"SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, "
    sql << "CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION "
    sql << "FROM INFORMATION_SCHEMA.COLUMNS "
    sql << "WHERE TABLE_NAME='%<table_name>s' AND TABLE_SCHEMA='' "
    sql << "AND COLUMN_NAME='%<column_name>s' " if column_name
    sql << "ORDER BY ORDINAL_POSITION ASC"
    sql % { table_name: table_name, column_name: column_name }
  end

  def self.register_select_tables_result spanner_mock_server
    sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''"

    table_catalog = Field.new name: "TABLE_CATALOG", type: Type.new(code: TypeCode::STRING)
    table_schema = Field.new name: "TABLE_SCHEMA", type: Type.new(code: TypeCode::STRING)
    table_name = Field.new name: "TABLE_NAME", type: Type.new(code: TypeCode::STRING)
    parent_table_name = Field.new name: "PARENT_TABLE_NAME", type: Type.new(code: TypeCode::STRING)
    on_delete_action = Field.new name: "ON_DELETE_ACTION", type: Type.new(code: TypeCode::STRING)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push table_catalog, table_schema, table_name, parent_table_name, on_delete_action
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "singers"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "albums"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "all_types"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "table_with_commit_timestamps"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "table_with_sequence"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "versioned_singers"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_singers_columns_result spanner_mock_server
    register_singers_columns_result_with_options spanner_mock_server, "singers", false
  end

  def self.register_versioned_singers_columns_result spanner_mock_server
    register_singers_columns_result_with_options spanner_mock_server, "versioned_singers", true
  end

  def self.register_singers_columns_result_with_options spanner_mock_server, table_name, with_version_column
    register_commit_timestamps_result spanner_mock_server, table_name

    sql = table_columns_sql table_name

    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    spanner_type = Field.new name: "SPANNER_TYPE", type: Type.new(code: TypeCode::STRING)
    is_nullable = Field.new name: "IS_NULLABLE", type: Type.new(code: TypeCode::STRING)
    generation_expression = Field.new name: "GENERATION_EXPRESSION", type: Type.new(code: TypeCode::STRING)
    column_default = Field.new name: "COLUMN_DEFAULT", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, generation_expression, column_default, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "id"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "first_name"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "last_name"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "last_performance"),
      Value.new(string_value: "TIMESTAMP"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "4")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "picture"),
      Value.new(string_value: "BYTES(MAX)"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "5")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "revenues"),
      Value.new(string_value: "NUMERIC"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "6")
    )
    result_set.rows.push row
    if with_version_column
      row = ListValue.new
      row.values.push(
        Value.new(string_value: "lock_version"),
        Value.new(string_value: "INT64"),
        Value.new(string_value: "NO"),
        Value.new(null_value: "NULL_VALUE"),
        Value.new(null_value: "NULL_VALUE"),
        Value.new(string_value: "7")
      )
      result_set.rows.push row
    end

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_singers_indexed_columns_result spanner_mock_server
    sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_indexes_result spanner_mock_server
    sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_TYPE='INDEX' AND SPANNER_IS_MANAGED=FALSE"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_primary_key_columns_result spanner_mock_server
    sql = self.primary_key_columns_sql "singers", parent_keys: false
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_primary_and_parent_key_columns_result spanner_mock_server
    sql = self.primary_key_columns_sql "singers", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_versioned_singers_primary_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "versioned_singers", parent_keys: false
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_versioned_singers_primary_and_parent_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "versioned_singers", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_albums_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "albums"

    sql = table_columns_sql "albums"

    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    spanner_type = Field.new name: "SPANNER_TYPE", type: Type.new(code: TypeCode::STRING)
    is_nullable = Field.new name: "IS_NULLABLE", type: Type.new(code: TypeCode::STRING)
    generation_expression = Field.new name: "GENERATION_EXPRESSION", type: Type.new(code: TypeCode::STRING)
    column_default = Field.new name: "COLUMN_DEFAULT", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, generation_expression, column_default, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "id"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "title"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "singer_id"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_albums_primary_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "albums", parent_keys: false
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_albums_primary_and_parent_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "albums", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_all_types_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "all_types"

    sql = table_columns_sql "all_types"

    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    spanner_type = Field.new name: "SPANNER_TYPE", type: Type.new(code: TypeCode::STRING)
    is_nullable = Field.new name: "IS_NULLABLE", type: Type.new(code: TypeCode::STRING)
    generation_expression = Field.new name: "GENERATION_EXPRESSION", type: Type.new(code: TypeCode::STRING)
    column_default = Field.new name: "COLUMN_DEFAULT", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, generation_expression, column_default, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "id"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_string"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_int64"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_float64"),
      Value.new(string_value: "FLOAT64"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "4")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_numeric"),
      Value.new(string_value: "NUMERIC"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "5")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_bool"),
      Value.new(string_value: "BOOL"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "6")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_bytes"),
      Value.new(string_value: "BYTES(MAX)"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "7")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_date"),
      Value.new(string_value: "DATE"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "8")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_timestamp"),
      Value.new(string_value: "TIMESTAMP"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "9")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_json"),
      Value.new(string_value: "JSON"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "10")
    )
    result_set.rows.push row

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_string"),
      Value.new(string_value: "ARRAY<STRING(MAX)>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "11")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_int64"),
      Value.new(string_value: "ARRAY<INT64>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "12")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_float64"),
      Value.new(string_value: "ARRAY<FLOAT64>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "13")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_numeric"),
      Value.new(string_value: "ARRAY<NUMERIC>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "14")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_bool"),
      Value.new(string_value: "ARRAY<BOOL>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "15")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_bytes"),
      Value.new(string_value: "ARRAY<BYTES(MAX)>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "16")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_date"),
      Value.new(string_value: "ARRAY<DATE>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "17")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_timestamp"),
      Value.new(string_value: "ARRAY<TIMESTAMP>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "18")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "col_array_json"),
      Value.new(string_value: "ARRAY<JSON>"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "19")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_all_types_primary_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "all_types", parent_keys: false
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_all_types_primary_and_parent_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "all_types", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_table_with_commit_timestamps_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "table_with_commit_timestamps", nil, "last_updated"

    sql = table_columns_sql "table_with_commit_timestamps"

    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    spanner_type = Field.new name: "SPANNER_TYPE", type: Type.new(code: TypeCode::STRING)
    is_nullable = Field.new name: "IS_NULLABLE", type: Type.new(code: TypeCode::STRING)
    generation_expression = Field.new name: "GENERATION_EXPRESSION", type: Type.new(code: TypeCode::STRING)
    column_default = Field.new name: "COLUMN_DEFAULT", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, generation_expression, column_default, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "id"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "value"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "last_updated"),
      Value.new(string_value: "TIMESTAMP"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_table_with_commit_timestamps_primary_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "table_with_commit_timestamps", parent_keys: false
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_table_with_commit_timestamps_primary_and_parent_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "table_with_commit_timestamps", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_table_with_sequence_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "table_with_sequence"

    sql = table_columns_sql "table_with_sequence"

    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    generation_expression = Google::Cloud::Spanner::V1::StructType::Field.new name: "GENERATION_EXPRESSION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, generation_expression, column_default, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Value.new(string_value: "id"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "GET_NEXT_SEQUENCE_VALUE(Sequence test_sequence)"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Value.new(string_value: "name"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Value.new(string_value: "last_updated"),
      Value.new(string_value: "TIMESTAMP"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_table_with_sequence_primary_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "table_with_sequence", parent_keys: false
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_table_with_sequence_primary_and_parent_key_columns_result spanner_mock_server
    sql = primary_key_columns_sql "table_with_sequence", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_empty_select_indexes_result spanner_mock_server, sql
    col_index_name = Field.new name: "INDEX_NAME", type: Type.new(code: TypeCode::STRING)
    col_index_type = Field.new name: "INDEX_TYPE", type: Type.new(code: TypeCode::STRING)
    col_is_unique = Field.new name: "IS_UNIQUE", type: Type.new(code: TypeCode::BOOL)
    col_is_null_filtered = Field.new name: "IS_NULL_FILTERED", type: Type.new(code: TypeCode::BOOL)
    col_parent_table_name = Field.new name: "PARENT_TABLE_NAME", type: Type.new(code: TypeCode::STRING)
    col_index_state = Field.new name: "INDEX_STATE", type: Type.new(code: TypeCode::STRING)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_index_name, col_index_type, col_is_unique, col_is_null_filtered, col_parent_table_name, col_index_state
    result_set = ResultSet.new metadata: metadata

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  private

  def self.register_commit_timestamps_result spanner_mock_server, table_name, column_name = nil, commit_timestamps_col = nil
    option_sql = +"SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME='#{table_name}' AND TABLE_SCHEMA=''"
    option_sql << " AND COLUMN_NAME='#{column_name}'" if column_name
    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    option_name = Field.new name: "OPTION_NAME", type: Type.new(code: TypeCode::STRING)
    option_type = Field.new name: "OPTION_TYPE", type: Type.new(code: TypeCode::STRING)
    option_value = Field.new name: "OPTION_VALUE", type: Type.new(code: TypeCode::STRING)
    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push column_name, option_name, option_type, option_value
    result_set = ResultSet.new metadata: metadata
    row = ListValue.new
    if commit_timestamps_col
      row.values.push(
        Value.new(string_value: commit_timestamps_col),
        Value.new(string_value: "allow_commit_timestamp"),
        Value.new(string_value: "BOOL"),
        Value.new(string_value: "TRUE"),
      )
    end
    result_set.rows.push row
    spanner_mock_server.put_statement_result option_sql, StatementResult.new(result_set)
  end

  def self.register_key_columns_result spanner_mock_server, sql
    index_name = Field.new name: "INDEX_NAME", type: Type.new(code: TypeCode::STRING)
    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    column_ordering = Field.new name: "COLUMN_ORDERING", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "PRIMARY_KEY"),
      Value.new(string_value: "id"),
      Value.new(string_value: "ASC"),
      Value.new(string_value: "1"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_join_table_primary_key_result spanner_mock_server
    sql = MockServerTests.primary_key_columns_sql "artists_musics", parent_keys: true
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_join_table_key_columns_result spanner_mock_server, table, col1, col2
    sql = primary_key_columns_sql table, parent_keys: false

    index_name = Field.new name: "INDEX_NAME", type: Type.new(code: TypeCode::STRING)
    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    column_ordering = Field.new name: "COLUMN_ORDERING", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "PRIMARY_KEY"),
      Value.new(string_value: col1),
      Value.new(string_value: "ASC"),
      Value.new(string_value: "1"),
    )
    result_set.rows.push row

    row = ListValue.new
    row.values.push(
      Value.new(string_value: "PRIMARY_KEY"),
      Value.new(string_value: col2),
      Value.new(string_value: "ASC"),
      Value.new(string_value: "2"),
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_join_table_columns_result spanner_mock_server, table_name, col1, col2
    register_commit_timestamps_result spanner_mock_server, table_name

    sql = table_columns_sql table_name

    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    spanner_type = Field.new name: "SPANNER_TYPE", type: Type.new(code: TypeCode::STRING)
    is_nullable = Field.new name: "IS_NULLABLE", type: Type.new(code: TypeCode::STRING)
    generation_expression = Field.new name: "GENERATION_EXPRESSION", type: Type.new(code: TypeCode::STRING)
    column_default = Field.new name: "COLUMN_DEFAULT", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, generation_expression, column_default, ordinal_position
    result_set = ResultSet.new metadata: metadata

    row = ListValue.new
    row.values.push(
      Value.new(string_value: col1),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row

    row = ListValue.new
    row.values.push(
      Value.new(string_value: col2),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

end
