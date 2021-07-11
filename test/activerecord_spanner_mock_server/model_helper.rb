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
  def self.create_random_singers_result(row_count, lock_version = false)
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson]
    col_id = Google::Cloud::Spanner::V1::StructType::Field.new name: "id", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_first_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "first_name", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    col_last_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "last_name", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    col_last_performance = Google::Cloud::Spanner::V1::StructType::Field.new name: "last_performance", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::TIMESTAMP)
    col_picture = Google::Cloud::Spanner::V1::StructType::Field.new name: "picture", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BYTES)
    col_revenues = Google::Cloud::Spanner::V1::StructType::Field.new name: "revenues", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::NUMERIC)
    col_lock_version = Google::Cloud::Spanner::V1::StructType::Field.new name: "lock_version", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push col_id, col_first_name, col_last_name, col_last_performance, col_picture, col_revenues
    metadata.row_type.fields.push col_lock_version if lock_version
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    (1..row_count).each { |_|
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s),
        Google::Protobuf::Value.new(string_value: first_names.sample),
        Google::Protobuf::Value.new(string_value: last_names.sample),
        Google::Protobuf::Value.new(string_value: StatementResult.random_timestamp_string),
        Google::Protobuf::Value.new(string_value: Base64.encode64(SecureRandom.alphanumeric(SecureRandom.random_number(10..200)))),
        Google::Protobuf::Value.new(string_value: SecureRandom.random_number(1000.0..1000000.0).to_s),
      )
      row.values.push Google::Protobuf::Value.new(string_value: lock_version.to_s) if lock_version
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.create_random_albums_result(row_count)
    adjectives = ["daily", "happy", "blue", "generous", "cooked", "bad", "open"]
    nouns = ["windows", "potatoes", "bank", "street", "tree", "glass", "bottle"]

    col_id = Google::Cloud::Spanner::V1::StructType::Field.new name: "id", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_title = Google::Cloud::Spanner::V1::StructType::Field.new name: "title", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    col_singer_id = Google::Cloud::Spanner::V1::StructType::Field.new name: "singer_id", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push col_id, col_title, col_singer_id
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    (1..row_count).each { |_|
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s),
        Google::Protobuf::Value.new(string_value: "#{adjectives.sample} #{nouns.sample}"),
        Google::Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s)
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.register_select_tables_result spanner_mock_server
    sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''"

    table_catalog = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_CATALOG", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    table_schema = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_SCHEMA", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    parent_table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    on_delete_action = Google::Cloud::Spanner::V1::StructType::Field.new name: "ON_DELETE_ACTION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push table_catalog, table_schema, table_name, parent_table_name, on_delete_action
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: "singers"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: "albums"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: "all_types"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: "table_with_commit_timestamps"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: "versioned_singers"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
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
    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='#{table_name}' ORDER BY ORDINAL_POSITION ASC"

    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BYTES)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, column_default, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "id"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "first_name"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "last_name"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "last_performance"),
      Google::Protobuf::Value.new(string_value: "TIMESTAMP"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "4")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "picture"),
      Google::Protobuf::Value.new(string_value: "BYTES(MAX)"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "5")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "revenues"),
      Google::Protobuf::Value.new(string_value: "NUMERIC"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "6")
    )
    result_set.rows.push row
    if with_version_column
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "lock_version"),
        Google::Protobuf::Value.new(string_value: "INT64"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "7")
      )
      result_set.rows.push row
    end

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_singers_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_versioned_singers_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'versioned_singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_versioned_singers_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'versioned_singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_albums_columns_result spanner_mock_server
    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='albums' ORDER BY ORDINAL_POSITION ASC"

    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BYTES)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, column_default, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "id"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "title"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "singer_id"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_albums_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_albums_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_all_types_columns_result spanner_mock_server
    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='all_types' ORDER BY ORDINAL_POSITION ASC"

    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BYTES)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, column_default, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "id"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_string"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_int64"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_float64"),
      Google::Protobuf::Value.new(string_value: "FLOAT64"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "4")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_numeric"),
      Google::Protobuf::Value.new(string_value: "NUMERIC"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "5")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_bool"),
      Google::Protobuf::Value.new(string_value: "BOOL"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "6")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_bytes"),
      Google::Protobuf::Value.new(string_value: "BYTES(MAX)"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "7")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_date"),
      Google::Protobuf::Value.new(string_value: "DATE"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "8")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_timestamp"),
      Google::Protobuf::Value.new(string_value: "TIMESTAMP"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "9")
    )
    result_set.rows.push row

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_string"),
      Google::Protobuf::Value.new(string_value: "ARRAY<STRING(MAX)>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "10")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_int64"),
      Google::Protobuf::Value.new(string_value: "ARRAY<INT64>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "11")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_float64"),
      Google::Protobuf::Value.new(string_value: "ARRAY<FLOAT64>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "12")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_numeric"),
      Google::Protobuf::Value.new(string_value: "ARRAY<NUMERIC>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "13")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_bool"),
      Google::Protobuf::Value.new(string_value: "ARRAY<BOOL>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "14")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_bytes"),
      Google::Protobuf::Value.new(string_value: "ARRAY<BYTES(MAX)>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "15")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_date"),
      Google::Protobuf::Value.new(string_value: "ARRAY<DATE>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "16")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "col_array_timestamp"),
      Google::Protobuf::Value.new(string_value: "ARRAY<TIMESTAMP>"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "17")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_all_types_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'all_types' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_all_types_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'all_types' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_table_with_commit_timestamps_columns_result spanner_mock_server
    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='table_with_commit_timestamps' ORDER BY ORDINAL_POSITION ASC"

    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BYTES)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push column_name, spanner_type, is_nullable, column_default, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "id"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "value"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "last_updated"),
      Google::Protobuf::Value.new(string_value: "TIMESTAMP"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_table_with_commit_timestamps_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'table_with_commit_timestamps' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  def self.register_table_with_commit_timestamps_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'table_with_commit_timestamps' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_key_columns_result spanner_mock_server, sql
  end

  private

  def self.register_key_columns_result spanner_mock_server, sql
    index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_ordering = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_ORDERING", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "PRIMARY_KEY"),
      Google::Protobuf::Value.new(string_value: "id"),
      Google::Protobuf::Value.new(string_value: "ASC"),
      Google::Protobuf::Value.new(string_value: "1"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end
end
