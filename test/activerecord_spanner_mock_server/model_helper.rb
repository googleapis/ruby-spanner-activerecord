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

def create_random_singers_result(row_count)
  first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy]
  last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson]
  col_id = V1::StructType::Field.new name: "id", type: V1::Type.new(code: V1::TypeCode::INT64)
  col_first_name = V1::StructType::Field.new name: "first_name", type: V1::Type.new(code: V1::TypeCode::STRING)
  col_last_name = V1::StructType::Field.new name: "last_name", type: V1::Type.new(code: V1::TypeCode::STRING)
  col_last_performance = V1::StructType::Field.new name: "last_performance", type: V1::Type.new(code: V1::TypeCode::TIMESTAMP)
  col_picture = V1::StructType::Field.new name: "picture", type: V1::Type.new(code: V1::TypeCode::BYTES)
  col_revenues = V1::StructType::Field.new name: "revenues", type: V1::Type.new(code: V1::TypeCode::NUMERIC)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push col_id, col_first_name, col_last_name, col_last_performance, col_picture, col_revenues
  result_set = V1::ResultSet.new metadata: metadata

  (1..row_count).each { |_|
    row = Protobuf::ListValue.new
    row.values.push(
      Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s),
      Protobuf::Value.new(string_value: first_names.sample),
      Protobuf::Value.new(string_value: last_names.sample),
      Protobuf::Value.new(string_value: StatementResult.random_timestamp_string),
      Protobuf::Value.new(string_value: Base64.encode64(SecureRandom.alphanumeric(SecureRandom.random_number(10..200)))),
      Protobuf::Value.new(string_value: SecureRandom.random_number(1000.0..1000000.0).to_s),
      )
    result_set.rows.push row
  }

  StatementResult.new result_set
end

def create_random_albums_result(row_count)
  adjectives = ["daily", "happy", "blue", "generous", "cooked", "bad", "open"]
  nouns = ["windows", "potatoes", "bank", "street", "tree", "glass", "bottle"]

  col_id = V1::StructType::Field.new name: "id", type: V1::Type.new(code: V1::TypeCode::INT64)
  col_title = V1::StructType::Field.new name: "title", type: V1::Type.new(code: V1::TypeCode::STRING)
  col_singer_id = V1::StructType::Field.new name: "singer_id", type: V1::Type.new(code: V1::TypeCode::INT64)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push col_id, col_title, col_singer_id
  result_set = V1::ResultSet.new metadata: metadata

  (1..row_count).each { |_|
    row = Protobuf::ListValue.new
    row.values.push(
      Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s),
      Protobuf::Value.new(string_value: "#{adjectives.sample} #{nouns.sample}"),
      Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s)
    )
    result_set.rows.push row
  }

  StatementResult.new result_set
end

def register_select_tables_result spanner_mock_server
  sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''"

  table_catalog = V1::StructType::Field.new name: "TABLE_CATALOG", type: V1::Type.new(code: V1::TypeCode::STRING)
  table_schema = V1::StructType::Field.new name: "TABLE_SCHEMA", type: V1::Type.new(code: V1::TypeCode::STRING)
  table_name = V1::StructType::Field.new name: "TABLE_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  parent_table_name = V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  on_delete_action = V1::StructType::Field.new name: "ON_DELETE_ACTION", type: V1::Type.new(code: V1::TypeCode::STRING)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push table_catalog, table_schema, table_name, parent_table_name, on_delete_action
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: ""),
    Protobuf::Value.new(string_value: ""),
    Protobuf::Value.new(string_value: "singers"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: ""),
    Protobuf::Value.new(string_value: ""),
    Protobuf::Value.new(string_value: "albums"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end

def register_singers_columns_result spanner_mock_server
  sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='singers' ORDER BY ORDINAL_POSITION ASC"

  column_name = V1::StructType::Field.new name: "COLUMN_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  spanner_type = V1::StructType::Field.new name: "SPANNER_TYPE", type: V1::Type.new(code: V1::TypeCode::STRING)
  is_nullable = V1::StructType::Field.new name: "IS_NULLABLE", type: V1::Type.new(code: V1::TypeCode::STRING)
  column_default = V1::StructType::Field.new name: "COLUMN_DEFAULT", type: V1::Type.new(code: V1::TypeCode::BYTES)
  ordinal_position = V1::StructType::Field.new name: "ORDINAL_POSITION", type: V1::Type.new(code: V1::TypeCode::INT64)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push column_name, spanner_type, is_nullable, column_default, ordinal_position
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "id"),
    Protobuf::Value.new(string_value: "INT64"),
    Protobuf::Value.new(string_value: "NO"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "1")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "first_name"),
    Protobuf::Value.new(string_value: "STRING(MAX)"),
    Protobuf::Value.new(string_value: "NO"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "2")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "last_name"),
    Protobuf::Value.new(string_value: "STRING(MAX)"),
    Protobuf::Value.new(string_value: "NO"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "3")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "last_performance"),
    Protobuf::Value.new(string_value: "TIMESTAMP"),
    Protobuf::Value.new(string_value: "YES"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "4")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "picture"),
    Protobuf::Value.new(string_value: "BYTES(MAX)"),
    Protobuf::Value.new(string_value: "YES"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "5")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "revenues"),
    Protobuf::Value.new(string_value: "NUMERIC"),
    Protobuf::Value.new(string_value: "YES"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "6")
  )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end

def register_singers_primary_key_result spanner_mock_server
  sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND INDEX_TYPE='PRIMARY_KEY' AND SPANNER_IS_MANAGED=FALSE"

  index_name = V1::StructType::Field.new name: "INDEX_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  index_type = V1::StructType::Field.new name: "INDEX_TYPE", type: V1::Type.new(code: V1::TypeCode::STRING)
  is_unique = V1::StructType::Field.new name: "IS_UNIQUE", type: V1::Type.new(code: V1::TypeCode::BOOL)
  is_null_filtered = V1::StructType::Field.new name: "IS_NULL_FILTERED", type: V1::Type.new(code: V1::TypeCode::BOOL)
  parent_table_name = V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  index_state = V1::StructType::Field.new name: "INDEX_STATE", type: V1::Type.new(code: V1::TypeCode::STRING)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push index_name, index_type, is_unique, is_null_filtered, parent_table_name, index_state
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "PRIMARY_KEY"), # INDEX_NAME
    Protobuf::Value.new(string_value: "PRIMARY_KEY"), # INDEX_TYPE
    Protobuf::Value.new(bool_value: true),
    Protobuf::Value.new(bool_value: false),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end

def register_singer_index_columns_result spanner_mock_server
  sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' ORDER BY ORDINAL_POSITION ASC"

  index_name = V1::StructType::Field.new name: "INDEX_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  column_name = V1::StructType::Field.new name: "COLUMN_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  column_ordering = V1::StructType::Field.new name: "COLUMN_ORDERING", type: V1::Type.new(code: V1::TypeCode::STRING)
  ordinal_position = V1::StructType::Field.new name: "ORDINAL_POSITION", type: V1::Type.new(code: V1::TypeCode::INT64)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "PRIMARY_KEY"),
    Protobuf::Value.new(string_value: "id"),
    Protobuf::Value.new(string_value: "ASC"),
    Protobuf::Value.new(string_value: "1"),
    )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end

def register_albums_columns_result spanner_mock_server
  sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='albums' ORDER BY ORDINAL_POSITION ASC"

  column_name = V1::StructType::Field.new name: "COLUMN_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  spanner_type = V1::StructType::Field.new name: "SPANNER_TYPE", type: V1::Type.new(code: V1::TypeCode::STRING)
  is_nullable = V1::StructType::Field.new name: "IS_NULLABLE", type: V1::Type.new(code: V1::TypeCode::STRING)
  column_default = V1::StructType::Field.new name: "COLUMN_DEFAULT", type: V1::Type.new(code: V1::TypeCode::BYTES)
  ordinal_position = V1::StructType::Field.new name: "ORDINAL_POSITION", type: V1::Type.new(code: V1::TypeCode::INT64)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push column_name, spanner_type, is_nullable, column_default, ordinal_position
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "id"),
    Protobuf::Value.new(string_value: "INT64"),
    Protobuf::Value.new(string_value: "NO"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "1")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "title"),
    Protobuf::Value.new(string_value: "STRING(MAX)"),
    Protobuf::Value.new(string_value: "NO"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "2")
  )
  result_set.rows.push row
  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "singer_id"),
    Protobuf::Value.new(string_value: "INT64"),
    Protobuf::Value.new(string_value: "NO"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(string_value: "3")
  )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end

def register_albums_primary_key_result spanner_mock_server
  sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND INDEX_TYPE='PRIMARY_KEY' AND SPANNER_IS_MANAGED=FALSE"

  index_name = V1::StructType::Field.new name: "INDEX_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  index_type = V1::StructType::Field.new name: "INDEX_TYPE", type: V1::Type.new(code: V1::TypeCode::STRING)
  is_unique = V1::StructType::Field.new name: "IS_UNIQUE", type: V1::Type.new(code: V1::TypeCode::BOOL)
  is_null_filtered = V1::StructType::Field.new name: "IS_NULL_FILTERED", type: V1::Type.new(code: V1::TypeCode::BOOL)
  parent_table_name = V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  index_state = V1::StructType::Field.new name: "INDEX_STATE", type: V1::Type.new(code: V1::TypeCode::STRING)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push index_name, index_type, is_unique, is_null_filtered, parent_table_name, index_state
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "PRIMARY_KEY"), # INDEX_NAME
    Protobuf::Value.new(string_value: "PRIMARY_KEY"), # INDEX_TYPE
    Protobuf::Value.new(bool_value: true),
    Protobuf::Value.new(bool_value: false),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    Protobuf::Value.new(null_value: "NULL_VALUE"),
    )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end

def register_albums_index_columns_result spanner_mock_server
  sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' ORDER BY ORDINAL_POSITION ASC"

  index_name = V1::StructType::Field.new name: "INDEX_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  column_name = V1::StructType::Field.new name: "COLUMN_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
  column_ordering = V1::StructType::Field.new name: "COLUMN_ORDERING", type: V1::Type.new(code: V1::TypeCode::STRING)
  ordinal_position = V1::StructType::Field.new name: "ORDINAL_POSITION", type: V1::Type.new(code: V1::TypeCode::INT64)

  metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
  metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
  result_set = V1::ResultSet.new metadata: metadata

  row = Protobuf::ListValue.new
  row.values.push(
    Protobuf::Value.new(string_value: "PRIMARY_KEY"),
    Protobuf::Value.new(string_value: "id"),
    Protobuf::Value.new(string_value: "ASC"),
    Protobuf::Value.new(string_value: "1"),
    )
  result_set.rows.push row

  spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
end
