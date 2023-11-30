# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

VERSION_7_1_0 = Gem::Version.create('7.1.0')

require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"

return if ActiveRecord::gem_version >= VERSION_7_1_0

require_relative "models/singer"
require_relative "models/album"

require "securerandom"

module TestInterleavedTables
  def self.create_random_singers_result(row_count, start_id = nil)
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson]
    col_singerid = Google::Cloud::Spanner::V1::StructType::Field.new name: "singerid", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_first_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "first_name", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    col_last_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "last_name", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push col_singerid, col_first_name, col_last_name
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    (0...row_count).each { |c|
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: (start_id ? start_id + c : SecureRandom.random_number(1000000)).to_s),
        Google::Protobuf::Value.new(string_value: first_names.sample),
        Google::Protobuf::Value.new(string_value: last_names.sample),
        )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.create_random_albums_result(row_count, start_id = nil, singer_id = nil)
    adjectives = ["daily", "happy", "blue", "generous", "cooked", "bad", "open"]
    nouns = ["windows", "potatoes", "bank", "street", "tree", "glass", "bottle"]

    col_albumid = Google::Cloud::Spanner::V1::StructType::Field.new name: "albumid", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_singerid = Google::Cloud::Spanner::V1::StructType::Field.new name: "singerid", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_title = Google::Cloud::Spanner::V1::StructType::Field.new name: "title", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push col_albumid, col_singerid, col_title
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    (0...row_count).each { |c|
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: (start_id ? start_id + c : SecureRandom.random_number(1000000)).to_s),
        Google::Protobuf::Value.new(string_value: (singer_id ? singer_id : SecureRandom.random_number(1000000)).to_s),
        Google::Protobuf::Value.new(string_value: "#{adjectives.sample} #{nouns.sample}")
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.create_random_tracks_result(row_count, start_id = nil, singer_id = nil, album_id = nil)
    adjectives = ["prominent", "unaware", "alternative", "eventual", "single", "unfamiliar", "criminal"]
    nouns = ["fold", "cleaner", "mass", "maintenance", "commentary", "classic", "assistant"]

    col_trackid = Google::Cloud::Spanner::V1::StructType::Field.new name: "trackid", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_singerid = Google::Cloud::Spanner::V1::StructType::Field.new name: "singerid", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_albumid = Google::Cloud::Spanner::V1::StructType::Field.new name: "albumid", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_title = Google::Cloud::Spanner::V1::StructType::Field.new name: "title", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    col_duration = Google::Cloud::Spanner::V1::StructType::Field.new name: "duration", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::NUMERIC)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push col_trackid, col_singerid, col_albumid, col_title, col_duration
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    (0...row_count).each { |c|
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: (start_id ? start_id + c : SecureRandom.random_number(1000000)).to_s),
        Google::Protobuf::Value.new(string_value: (singer_id ? singer_id : SecureRandom.random_number(1000000)).to_s),
        Google::Protobuf::Value.new(string_value: (album_id ? album_id : SecureRandom.random_number(1000000)).to_s),
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
      Google::Protobuf::Value.new(string_value: "singers"),
      Google::Protobuf::Value.new(string_value: "NO ACTION"),
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: ""),
      Google::Protobuf::Value.new(string_value: "tracks"),
      Google::Protobuf::Value.new(string_value: "albums"),
      Google::Protobuf::Value.new(string_value: "CASCADE"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_singers_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "singers"

    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='singers' ORDER BY ORDINAL_POSITION ASC"

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
      Google::Protobuf::Value.new(string_value: "singerid"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
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
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_commit_timestamps_result spanner_mock_server, table_name, column_name = nil, commit_timestamps_col = nil
    option_sql = +"SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME='#{table_name}'"
    option_sql << " AND COLUMN_NAME='#{column_name}'" if column_name
    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    option_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "OPTION_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    option_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "OPTION_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    option_value = Google::Cloud::Spanner::V1::StructType::Field.new name: "OPTION_VALUE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push column_name, option_name, option_type, option_value
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata
    row = Google::Protobuf::ListValue.new
    if commit_timestamps_col
      row.values.push(
        Google::Protobuf::Value.new(string_value: commit_timestamps_col),
        Google::Protobuf::Value.new(string_value: "allow_commit_timestamp"),
        Google::Protobuf::Value.new(string_value: "BOOL"),
        Google::Protobuf::Value.new(string_value: "TRUE"),
        )
    end
    result_set.rows.push row
    spanner_mock_server.put_statement_result option_sql, StatementResult.new(result_set)
  end

  def self.register_singers_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_singers_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_singers_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_key_columns_result spanner_mock_server, sql
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
      Google::Protobuf::Value.new(string_value: "singerid"),
      Google::Protobuf::Value.new(string_value: "ASC"),
      Google::Protobuf::Value.new(string_value: "1"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_albums_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "albums"

    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='albums' ORDER BY ORDINAL_POSITION ASC"

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
      Google::Protobuf::Value.new(string_value: "albumid"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "singerid"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "title"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_albums_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_albums_key_columns_result spanner_mock_server, sql, false
  end

  def self.register_albums_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_albums_key_columns_result spanner_mock_server, sql, true
  end

  def self.register_albums_key_columns_result spanner_mock_server, sql, include_parent_key
    index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_ordering = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_ORDERING", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    if include_parent_key
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "PRIMARY_KEY"),
        Google::Protobuf::Value.new(string_value: "singerid"),
        Google::Protobuf::Value.new(string_value: "ASC"),
        Google::Protobuf::Value.new(string_value: "1"),
      )
      result_set.rows.push row
    end
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "PRIMARY_KEY"),
      Google::Protobuf::Value.new(string_value: "albumid"),
      Google::Protobuf::Value.new(string_value: "ASC"),
      Google::Protobuf::Value.new(string_value: "2"),
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_tracks_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "tracks"

    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='tracks' ORDER BY ORDINAL_POSITION ASC"

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
      Google::Protobuf::Value.new(string_value: "trackid"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "singerid"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "albumid"),
      Google::Protobuf::Value.new(string_value: "INT64"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "title"),
      Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
      Google::Protobuf::Value.new(string_value: "NO"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "4")
    )
    result_set.rows.push row
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "duration"),
      Google::Protobuf::Value.new(string_value: "NUMERIC"),
      Google::Protobuf::Value.new(string_value: "YES"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
      Google::Protobuf::Value.new(string_value: "5")
    )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_tracks_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'tracks' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_tracks_key_columns_result spanner_mock_server, sql, false
  end

  def self.register_tracks_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'tracks' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_tracks_key_columns_result spanner_mock_server, sql, true
  end

  def self.register_tracks_key_columns_result spanner_mock_server, sql, include_parent_key
    index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    column_ordering = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_ORDERING", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    if include_parent_key
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "PRIMARY_KEY"),
        Google::Protobuf::Value.new(string_value: "singerid"),
        Google::Protobuf::Value.new(string_value: "ASC"),
        Google::Protobuf::Value.new(string_value: "1"),
        )
      result_set.rows.push row
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "PRIMARY_KEY"),
        Google::Protobuf::Value.new(string_value: "albumid"),
        Google::Protobuf::Value.new(string_value: "ASC"),
        Google::Protobuf::Value.new(string_value: "2"),
        )
      result_set.rows.push row
    end
    row = Google::Protobuf::ListValue.new
    row.values.push(
      Google::Protobuf::Value.new(string_value: "PRIMARY_KEY"),
      Google::Protobuf::Value.new(string_value: "trackid"),
      Google::Protobuf::Value.new(string_value: "ASC"),
      Google::Protobuf::Value.new(string_value: "3"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end
end
