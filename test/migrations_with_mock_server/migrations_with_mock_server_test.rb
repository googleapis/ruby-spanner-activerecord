# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require_relative "../mock_server/spanner_mock_server"
require_relative "../mock_server/database_admin_mock_server"
require_relative "../test_helper"

require "securerandom"

# Tests executing a simple migration on a mock Spanner server.
class SpannerMigrationsMockServerTest < Minitest::Test
  def setup
    super
    @server = GRPC::RpcServer.new
    @port = @server.add_http2_port "localhost:0", :this_port_is_insecure
    @mock = SpannerMockServer.new
    @database_admin_mock = DatabaseAdminMockServer.new
    @server.handle @mock
    @server.handle @database_admin_mock
    # Run the server in a separate thread
    @server_thread = Thread.new do
      @server.run
    end
    # Register INFORMATION_SCHEMA queries on the mock server.
    register_schema_migrations_table_result
    register_schema_migrations_columns_result
    register_ar_internal_metadata_table_result
    register_ar_internal_metadata_columns_result
    register_ar_internal_metadata_results
    register_ar_internal_metadata_insert_result

    ActiveRecord::Base.establish_connection(
      adapter: "spanner",
      emulator_host: "localhost:#{@port}",
      project: "test-project",
      instance: "test-instance",
      database: "testdb"
    )
    ActiveRecord::Base.logger = nil
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    super
    ActiveRecord::Base.connection_pool.disconnect!
    @server.stop
    @server_thread.exit
  end

  def test_execute_migrations
    context = ActiveRecord::MigrationContext.new(
      "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
      ActiveRecord::SchemaMigration
    )

    # Register migration result for the current version (nil) to the new version (1).
    register_version_result nil, "1"

    context.migrate

    # The migration should create the migration tables and the singers and albums tables in one request.
    ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Admin::UpdateDatabaseDdlRequest) }
    assert_equal 3, ddl_requests.length
    assert_equal 1, ddl_requests[0].statements.length
    assert ddl_requests[0].statements[0].starts_with? "CREATE TABLE `schema_migrations`"
    assert_equal 1, ddl_requests[1].statements.length
    assert ddl_requests[1].statements[0].starts_with? "CREATE TABLE `ar_internal_metadata`"
    # The actual migration should be executed as one batch.
    assert_equal 2, ddl_requests[2].statements.length
    assert ddl_requests[2].statements[0].starts_with? "CREATE TABLE `singers`"
    assert ddl_requests[2].statements[1].starts_with? "CREATE TABLE `albums`"
  end

  def register_schema_migrations_table_result
    sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='schema_migrations'"
    register_empty_select_tables_result sql
  end

  def register_schema_migrations_columns_result
    # CREATE TABLE `schema_migrations` (`version` STRING(MAX) NOT NULL) PRIMARY KEY (`version`)
    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='schema_migrations' ORDER BY ORDINAL_POSITION ASC"

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
      Protobuf::Value.new(string_value: "version"),
      Protobuf::Value.new(string_value: "STRING(MAX)"),
      Protobuf::Value.new(string_value: "NO"),
      Protobuf::Value.new(null_value: "NULL_VALUE"),
      Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_ar_internal_metadata_table_result
    sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='ar_internal_metadata'"
    register_empty_select_tables_result sql
  end

  def register_ar_internal_metadata_columns_result
    # CREATE TABLE `ar_internal_metadata` (`key` STRING(MAX) NOT NULL, `value` STRING(MAX), `created_at` TIMESTAMP NOT NULL, `updated_at` TIMESTAMP NOT NULL) PRIMARY KEY (`key`)
    sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='ar_internal_metadata' ORDER BY ORDINAL_POSITION ASC"

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
      Protobuf::Value.new(string_value: "key"),
      Protobuf::Value.new(string_value: "STRING(MAX)"),
      Protobuf::Value.new(string_value: "NO"),
      Protobuf::Value.new(null_value: "NULL_VALUE"),
      Protobuf::Value.new(string_value: "1")
    )
    result_set.rows.push row
    row = Protobuf::ListValue.new
    row.values.push(
      Protobuf::Value.new(string_value: "value"),
      Protobuf::Value.new(string_value: "STRING(MAX)"),
      Protobuf::Value.new(string_value: "YES"),
      Protobuf::Value.new(null_value: "NULL_VALUE"),
      Protobuf::Value.new(string_value: "2")
    )
    result_set.rows.push row
    row = Protobuf::ListValue.new
    row.values.push(
      Protobuf::Value.new(string_value: "created_at"),
      Protobuf::Value.new(string_value: "TIMESTAMP"),
      Protobuf::Value.new(string_value: "NO"),
      Protobuf::Value.new(null_value: "NULL_VALUE"),
      Protobuf::Value.new(string_value: "3")
    )
    result_set.rows.push row
    row = Protobuf::ListValue.new
    row.values.push(
      Protobuf::Value.new(string_value: "updated_at"),
      Protobuf::Value.new(string_value: "TIMESTAMP"),
      Protobuf::Value.new(string_value: "NO"),
      Protobuf::Value.new(null_value: "NULL_VALUE"),
      Protobuf::Value.new(string_value: "4")
    )
    result_set.rows.push row

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_ar_internal_metadata_results
    # CREATE TABLE `ar_internal_metadata` (`key` STRING(MAX) NOT NULL, `value` STRING(MAX), `created_at` TIMESTAMP NOT NULL, `updated_at` TIMESTAMP NOT NULL) PRIMARY KEY (`key`)
    sql = "SELECT `ar_internal_metadata`.* FROM `ar_internal_metadata` WHERE `ar_internal_metadata`.`key` = 'environment' LIMIT 1"

    key = V1::StructType::Field.new name: "key", type: V1::Type.new(code: V1::TypeCode::STRING)
    value = V1::StructType::Field.new name: "value", type: V1::Type.new(code: V1::TypeCode::STRING)
    created_at = V1::StructType::Field.new name: "created_at", type: V1::Type.new(code: V1::TypeCode::TIMESTAMP)
    updated_at = V1::StructType::Field.new name: "updated_at", type: V1::Type.new(code: V1::TypeCode::TIMESTAMP)

    metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
    metadata.row_type.fields.push key, value, created_at, updated_at
    result_set = V1::ResultSet.new metadata: metadata

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_ar_internal_metadata_insert_result
    sql = "INSERT INTO `ar_internal_metadata` (`key`, `value`, `created_at`, `updated_at`) VALUES ('environment', 'default_env', '%"
    @mock.put_statement_result sql, StatementResult.new(1)
  end

  def register_empty_select_tables_result(sql)
    table_catalog = V1::StructType::Field.new name: "TABLE_CATALOG", type: V1::Type.new(code: V1::TypeCode::STRING)
    table_schema = V1::StructType::Field.new name: "TABLE_SCHEMA", type: V1::Type.new(code: V1::TypeCode::STRING)
    table_name = V1::StructType::Field.new name: "TABLE_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
    parent_table_name = V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: V1::Type.new(code: V1::TypeCode::STRING)
    on_delete_action = V1::StructType::Field.new name: "ON_DELETE_ACTION", type: V1::Type.new(code: V1::TypeCode::STRING)

    metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
    metadata.row_type.fields.push table_catalog, table_schema, table_name, parent_table_name, on_delete_action
    result_set = V1::ResultSet.new metadata: metadata

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_version_result(from_version, to_version)
    sql = "SELECT `schema_migrations`.`version` FROM `schema_migrations` ORDER BY `schema_migrations`.`version` ASC"

    version_column = V1::StructType::Field.new name: "version", type: V1::Type.new(code: V1::TypeCode::STRING)

    metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
    metadata.row_type.fields.push version_column
    result_set = V1::ResultSet.new metadata: metadata

    if from_version
      row = Protobuf::ListValue.new
      row.values.push Protobuf::Value.new(string_value: from_version)
      result_set.rows.push row
    end

    @mock.put_statement_result sql, StatementResult.new(result_set)

    update_sql = "INSERT INTO `schema_migrations` (`version`) VALUES ('#{to_version}')"
    @mock.put_statement_result update_sql, StatementResult.new(1)
  end
end
