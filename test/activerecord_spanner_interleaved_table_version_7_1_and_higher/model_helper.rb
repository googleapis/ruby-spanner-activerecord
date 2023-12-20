# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"

return if ActiveRecord::gem_version < Gem::Version.create('7.1.0')

require_relative "models/singer"
require_relative "models/album"

require "securerandom"

module TestInterleavedTables_7_1_AndHigher
  StructType = Google::Cloud::Spanner::V1::StructType
  Field = Google::Cloud::Spanner::V1::StructType::Field
  ResultSetMetadata = Google::Cloud::Spanner::V1::ResultSetMetadata
  ResultSet = Google::Cloud::Spanner::V1::ResultSet
  ListValue = Google::Protobuf::ListValue
  Value = Google::Protobuf::Value
  ResultSetStats = Google::Cloud::Spanner::V1::ResultSetStats

  TypeCode = Google::Cloud::Spanner::V1::TypeCode
  Type = Google::Cloud::Spanner::V1::Type

  def self.create_random_singers_result(row_count, start_id = nil)
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson]
    col_singerid = Field.new name: "singerid", type: Type.new(code: TypeCode::INT64)
    col_first_name = Field.new name: "first_name", type: Type.new(code: TypeCode::STRING)
    col_last_name = Field.new name: "last_name", type: Type.new(code: TypeCode::STRING)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_singerid, col_first_name, col_last_name
    result_set = ResultSet.new metadata: metadata

    (0...row_count).each { |c|
      row = ListValue.new
      row.values.push(
        Value.new(string_value: (start_id ? start_id + c : SecureRandom.random_number(1000000)).to_s),
        Value.new(string_value: first_names.sample),
        Value.new(string_value: last_names.sample),
        )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.create_random_albums_result(row_count, start_id = nil, singer_id = nil)
    adjectives = ["daily", "happy", "blue", "generous", "cooked", "bad", "open"]
    nouns = ["windows", "potatoes", "bank", "street", "tree", "glass", "bottle"]

    col_albumid = Field.new name: "albumid", type: Type.new(code: TypeCode::INT64)
    col_singerid = Field.new name: "singerid", type: Type.new(code: TypeCode::INT64)
    col_title = Field.new name: "title", type: Type.new(code: TypeCode::STRING)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_albumid, col_singerid, col_title
    result_set = ResultSet.new metadata: metadata

    (0...row_count).each { |c|
      row = ListValue.new
      row.values.push(
        Value.new(string_value: (start_id ? start_id + c : SecureRandom.random_number(1000000)).to_s),
        Value.new(string_value: (singer_id ? singer_id : SecureRandom.random_number(1000000)).to_s),
        Value.new(string_value: "#{adjectives.sample} #{nouns.sample}")
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.create_random_tracks_result(row_count, start_id = nil, singer_id = nil, album_id = nil)
    adjectives = ["prominent", "unaware", "alternative", "eventual", "single", "unfamiliar", "criminal"]
    nouns = ["fold", "cleaner", "mass", "maintenance", "commentary", "classic", "assistant"]

    col_trackid = Field.new name: "trackid", type: Type.new(code: TypeCode::INT64)
    col_singerid = Field.new name: "singerid", type: Type.new(code: TypeCode::INT64)
    col_albumid = Field.new name: "albumid", type: Type.new(code: TypeCode::INT64)
    col_title = Field.new name: "title", type: Type.new(code: TypeCode::STRING)
    col_duration = Field.new name: "duration", type: Type.new(code: TypeCode::NUMERIC)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push col_trackid, col_singerid, col_albumid, col_title, col_duration
    result_set = ResultSet.new metadata: metadata

    (0...row_count).each { |c|
      row = ListValue.new
      row.values.push(
        Value.new(string_value: (start_id ? start_id + c : SecureRandom.random_number(1000000)).to_s),
        Value.new(string_value: (singer_id ? singer_id : SecureRandom.random_number(1000000)).to_s),
        Value.new(string_value: (album_id ? album_id : SecureRandom.random_number(1000000)).to_s),
        Value.new(string_value: "#{adjectives.sample} #{nouns.sample}"),
        Value.new(string_value: SecureRandom.random_number(1000000).to_s)
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
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
      Value.new(string_value: "singers"),
      Value.new(string_value: "NO ACTION"),
      )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: ""),
      Value.new(string_value: ""),
      Value.new(string_value: "tracks"),
      Value.new(string_value: "albums"),
      Value.new(string_value: "CASCADE"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_singers_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "singers"

    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='singers' ORDER BY ORDINAL_POSITION ASC"

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
      Value.new(string_value: "singerid"),
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

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_commit_timestamps_result spanner_mock_server, table_name, column_name = nil, commit_timestamps_col = nil
    option_sql = +"SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE FROM INFORMATION_SCHEMA.COLUMN_OPTIONS WHERE TABLE_NAME='#{table_name}'"
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

  def self.register_singers_primary_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN (   SELECT COLUMN_NAME   FROM TABLE_PK_COLS   WHERE TABLE_NAME = T.PARENT_TABLE_NAME )) ORDER BY ORDINAL_POSITION"
    register_singers_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_primary_and_parent_key_columns_result spanner_mock_server
    sql = "WITH TABLE_PK_COLS AS ( SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS C WHERE C.INDEX_TYPE = 'PRIMARY_KEY' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '') SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM TABLE_PK_COLS INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) WHERE TABLE_NAME = 'singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION"
    register_singers_key_columns_result spanner_mock_server, sql
  end

  def self.register_singers_key_columns_result spanner_mock_server, sql
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
      Value.new(string_value: "singerid"),
      Value.new(string_value: "ASC"),
      Value.new(string_value: "1"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_albums_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "albums"

    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='albums' ORDER BY ORDINAL_POSITION ASC"

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
      Value.new(string_value: "albumid"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "singerid"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "title"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
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
    index_name = Field.new name: "INDEX_NAME", type: Type.new(code: TypeCode::STRING)
    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    column_ordering = Field.new name: "COLUMN_ORDERING", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = ResultSet.new metadata: metadata

    if include_parent_key
      row = ListValue.new
      row.values.push(
        Value.new(string_value: "PRIMARY_KEY"),
        Value.new(string_value: "singerid"),
        Value.new(string_value: "ASC"),
        Value.new(string_value: "1"),
        )
      result_set.rows.push row
    end
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "PRIMARY_KEY"),
      Value.new(string_value: "albumid"),
      Value.new(string_value: "ASC"),
      Value.new(string_value: "2"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end

  def self.register_tracks_columns_result spanner_mock_server
    register_commit_timestamps_result spanner_mock_server, "tracks"

    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='tracks' ORDER BY ORDINAL_POSITION ASC"

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
      Value.new(string_value: "trackid"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "singerid"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "albumid"),
      Value.new(string_value: "INT64"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "title"),
      Value.new(string_value: "STRING(MAX)"),
      Value.new(string_value: "NO"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "4")
    )
    result_set.rows.push row
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "duration"),
      Value.new(string_value: "NUMERIC"),
      Value.new(string_value: "YES"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(null_value: "NULL_VALUE"),
      Value.new(string_value: "5")
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
    index_name = Field.new name: "INDEX_NAME", type: Type.new(code: TypeCode::STRING)
    column_name = Field.new name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)
    column_ordering = Field.new name: "COLUMN_ORDERING", type: Type.new(code: TypeCode::STRING)
    ordinal_position = Field.new name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64)

    metadata = ResultSetMetadata.new row_type: StructType.new
    metadata.row_type.fields.push index_name, column_name, column_ordering, ordinal_position
    result_set = ResultSet.new metadata: metadata

    if include_parent_key
      row = ListValue.new
      row.values.push(
        Value.new(string_value: "PRIMARY_KEY"),
        Value.new(string_value: "singerid"),
        Value.new(string_value: "ASC"),
        Value.new(string_value: "1"),
        )
      result_set.rows.push row
      row = ListValue.new
      row.values.push(
        Value.new(string_value: "PRIMARY_KEY"),
        Value.new(string_value: "albumid"),
        Value.new(string_value: "ASC"),
        Value.new(string_value: "2"),
        )
      result_set.rows.push row
    end
    row = ListValue.new
    row.values.push(
      Value.new(string_value: "PRIMARY_KEY"),
      Value.new(string_value: "trackid"),
      Value.new(string_value: "ASC"),
      Value.new(string_value: "3"),
      )
    result_set.rows.push row

    spanner_mock_server.put_statement_result sql, StatementResult.new(result_set)
  end
end
