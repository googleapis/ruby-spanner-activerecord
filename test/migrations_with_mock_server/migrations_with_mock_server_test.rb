# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "securerandom"

require_relative "../test_helper"
require_relative "../mock_server/spanner_mock_server"
require_relative "../mock_server/database_admin_mock_server"
require_relative "models/album"
require_relative "models/singer"
require_relative "models/track"

module TestMigrationsWithMockServer
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
      @server.wait_till_running
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
      ActiveRecord::Base.connection_pool.disconnect!
      @server.stop
      @server_thread.exit
      super
    end

    def test_execute_migrations
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )

      # Register migration result for the current version (nil) to the new version (1).
      register_version_result nil, "1"

      context.migrate 1

      # The migration should create the migration tables and the singers and albums tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert ddl_requests[0].statements[0].starts_with? "CREATE TABLE `schema_migrations`"
      assert_equal 1, ddl_requests[1].statements.length
      assert ddl_requests[1].statements[0].starts_with? "CREATE TABLE `ar_internal_metadata`"
      # The actual migration should be executed as one batch.
      assert_equal 5, ddl_requests[2].statements.length
      assert_equal(
        "CREATE TABLE `singers` (`singerid` INT64 NOT NULL, `first_name` STRING(200), `last_name` STRING(MAX)) PRIMARY KEY (`singerid`)",
            ddl_requests[2].statements[0]
      )
      assert ddl_requests[2].statements[1].starts_with? "CREATE TABLE `albums`"
      assert ddl_requests[2].statements[2].starts_with? "ALTER TABLE `albums` ADD CONSTRAINT"
      assert_equal "ALTER TABLE `singers` ADD COLUMN `place_of_birth` STRING(MAX)", ddl_requests[2].statements[3]
      assert_equal(
        "CREATE TABLE `albums_singers` (`singer_id` INT64 NOT NULL, `album_id` INT64 NOT NULL) PRIMARY KEY (`singer_id`, `album_id`)",
        ddl_requests[2].statements[4]
      )
    end

    def test_execute_migration_without_batching
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )

      # Simulate upgrading from version 1 to version 2.
      register_version_result "1", "2"

      context.migrate 2

      # The migration should create the migration tables and the singers and albums tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 4, ddl_requests.length

      # The migration statements should not be executed in a batch.
      assert_equal 1, ddl_requests[2].statements.length
      assert_equal 1, ddl_requests[3].statements.length
      assert_equal(
        "CREATE TABLE `table1` (`id` INT64 NOT NULL, `col1` STRING(MAX), `col2` STRING(MAX)) PRIMARY KEY (`id`)",
        ddl_requests[2].statements[0]
      )
      assert_equal(
        "CREATE TABLE `table2` (`id` INT64 NOT NULL, `col1` STRING(MAX), `col2` STRING(MAX)) PRIMARY KEY (`id`)",
        ddl_requests[3].statements[0]
      )
    end

    def test_create_all_native_migration_types
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )

      register_version_result "1", "3"

      context.migrate 3

      # The migration should create the migration tables and the singers and albums tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      # CREATE TABLE `types_table` (`id` INT64 NOT NULL, `col_string` STRING(MAX), `col_text` STRING(MAX),
      # `col_integer` INT64, `col_bigint` INT64, `col_float` FLOAT64, `col_decimal` FLOAT64, `col_numeric` numeric,
      # `col_datetime` TIMESTAMP, `col_time` TIMESTAMP, `col_date` DATE, `col_binary` BYTES(MAX), `col_boolean` BOOL
      # `col_array_string` ARRAY<STRING(MAX)>, `col_array_text` ARRAY<STRING(MAX)>, `col_array_integer` ARRAY<INT64>,
      # `col_array_bigint` ARRAY<INT64>, `col_array_float` ARRAY<FLOAT64>, `col_array_decimal` ARRAY<FLOAT64>,
      # `col_array_numeric` ARRAY<NUMERIC>, `col_array_datetime` ARRAY<TIMESTAMP>, `col_array_time` ARRAY<TIMESTAMP>,
      # `col_array_date` ARRAY<DATE>, `col_array_binary` ARRAY<BYTES(MAX)>, `col_array_boolean` ARRAY<BOOL>,
      # ) PRIMARY KEY (`id`)
      expectedDdl = +"CREATE TABLE `types_table` ("
      expectedDdl << "`id` INT64 NOT NULL, "
      expectedDdl << "`col_string` STRING(MAX), "
      expectedDdl << "`col_text` STRING(MAX), "
      expectedDdl << "`col_integer` INT64, "
      expectedDdl << "`col_bigint` INT64, "
      expectedDdl << "`col_float` FLOAT64, "
      expectedDdl << "`col_decimal` NUMERIC, "
      expectedDdl << "`col_numeric` NUMERIC, "
      expectedDdl << "`col_datetime` TIMESTAMP, "
      expectedDdl << "`col_time` TIMESTAMP, "
      expectedDdl << "`col_date` DATE, "
      expectedDdl << "`col_binary` BYTES(MAX), "
      expectedDdl << "`col_boolean` BOOL, "
      expectedDdl << "`col_array_string` ARRAY<STRING(MAX)>, "
      expectedDdl << "`col_array_text` ARRAY<STRING(MAX)>, "
      expectedDdl << "`col_array_integer` ARRAY<INT64>, "
      expectedDdl << "`col_array_bigint` ARRAY<INT64>, "
      expectedDdl << "`col_array_float` ARRAY<FLOAT64>, "
      expectedDdl << "`col_array_decimal` ARRAY<NUMERIC>, "
      expectedDdl << "`col_array_numeric` ARRAY<NUMERIC>, "
      expectedDdl << "`col_array_datetime` ARRAY<TIMESTAMP>, "
      expectedDdl << "`col_array_time` ARRAY<TIMESTAMP>, "
      expectedDdl << "`col_array_date` ARRAY<DATE>, "
      expectedDdl << "`col_array_binary` ARRAY<BYTES(MAX)>, "
      expectedDdl << "`col_array_boolean` ARRAY<BOOL>) "
      expectedDdl << "PRIMARY KEY (`id`)"

      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_interleaved_table
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )

      register_version_result "1", "4"

      context.migrate 4

      # The migration should create the migration tables and the singers, albums and tracks tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 3, ddl_requests[2].statements.length

      expectedDdl = "CREATE TABLE `singers` "
      expectedDdl << "(`singerid` INT64 NOT NULL, `first_name` STRING(200), `last_name` STRING(MAX)) "
      expectedDdl << "PRIMARY KEY (`singerid`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]

      expectedDdl = "CREATE TABLE `albums` "
      expectedDdl << "(`albumid` INT64 NOT NULL, `singerid` INT64 NOT NULL, `title` STRING(MAX)"
      expectedDdl << ") PRIMARY KEY (`singerid`, `albumid`), INTERLEAVE IN PARENT `singers`"
      assert_equal expectedDdl, ddl_requests[2].statements[1]

      expectedDdl = "CREATE TABLE `tracks` "
      expectedDdl << "(`trackid` INT64 NOT NULL, `singerid` INT64 NOT NULL, `albumid` INT64 NOT NULL, `title` STRING(MAX), `duration` NUMERIC)"
      expectedDdl << " PRIMARY KEY (`singerid`, `albumid`, `trackid`), INTERLEAVE IN PARENT `albums` ON DELETE CASCADE"
      assert_equal expectedDdl, ddl_requests[2].statements[2]
    end

    def test_create_table_with_commit_timestamp
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )

      register_version_result "1", "5"

      context.migrate 5

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE TABLE `table1` "
      expectedDdl << "(`id` INT64 NOT NULL, `value` STRING(MAX), `last_updated` TIMESTAMP OPTIONS (allow_commit_timestamp = true)) "
      expectedDdl << "PRIMARY KEY (`id`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_create_table_with_generated_column
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )

      register_version_result "1", "6"

      context.migrate 6

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE TABLE `singers` "
      expectedDdl << "(`id` INT64 NOT NULL, `first_name` STRING(100), `last_name` STRING(200), "
      expectedDdl << "`full_name` STRING(300) AS (COALESCE(first_name || ' ', '') || last_name) STORED) "
      expectedDdl << "PRIMARY KEY (`id`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_interleaved_index
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_table_sql, "albums", "singers", "NO_ACTION"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singerid_and_title' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singerid_and_title' AND SPANNER_IS_MANAGED=FALSE"
      register_empty_select_indexes_result select_indexes_sql
      register_version_result "1", "7"

      context.migrate 7

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE INDEX `index_albums_on_singerid_and_title` ON `albums` (`singerid`, `title`), INTERLEAVE IN `singers`"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_null_filtered_index
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_picture' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_picture' AND SPANNER_IS_MANAGED=FALSE"
      register_empty_select_indexes_result select_indexes_sql
      register_version_result "1", "8"

      context.migrate 8

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE NULL_FILTERED INDEX `index_singers_on_picture` ON `singers` (`picture`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_index_storing
      context = ActiveRecord::MigrationContext.new(
        "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        ActiveRecord::SchemaMigration
      )
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_full_name' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_full_name' AND SPANNER_IS_MANAGED=FALSE"
      register_empty_select_indexes_result select_indexes_sql
      register_version_result "1", "9"

      context.migrate 9

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE INDEX `index_singers_on_full_name` ON `singers` (`full_name`) STORING (`first_name`, `last_name`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def register_schema_migrations_table_result
      sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='schema_migrations'"
      register_empty_select_tables_result sql
    end

    def register_schema_migrations_columns_result
      # CREATE TABLE `schema_migrations` (`version` STRING(MAX) NOT NULL) PRIMARY KEY (`version`)
      sql = "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='schema_migrations' ORDER BY ORDINAL_POSITION ASC"

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
        Google::Protobuf::Value.new(string_value: "version"),
        Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "1")
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
        Google::Protobuf::Value.new(string_value: "key"),
        Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "1")
      )
      result_set.rows.push row
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "value"),
        Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
        Google::Protobuf::Value.new(string_value: "YES"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "2")
      )
      result_set.rows.push row
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "created_at"),
        Google::Protobuf::Value.new(string_value: "TIMESTAMP"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "3")
      )
      result_set.rows.push row
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: "updated_at"),
        Google::Protobuf::Value.new(string_value: "TIMESTAMP"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "4")
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_ar_internal_metadata_results
      # CREATE TABLE `ar_internal_metadata` (`key` STRING(MAX) NOT NULL, `value` STRING(MAX), `created_at` TIMESTAMP NOT NULL, `updated_at` TIMESTAMP NOT NULL) PRIMARY KEY (`key`)
      sql = "SELECT `ar_internal_metadata`.* FROM `ar_internal_metadata` WHERE `ar_internal_metadata`.`key` = @key_1 LIMIT @LIMIT_2"

      key = Google::Cloud::Spanner::V1::StructType::Field.new name: "key", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      value = Google::Cloud::Spanner::V1::StructType::Field.new name: "value", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      created_at = Google::Cloud::Spanner::V1::StructType::Field.new name: "created_at", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::TIMESTAMP)
      updated_at = Google::Cloud::Spanner::V1::StructType::Field.new name: "updated_at", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::TIMESTAMP)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push key, value, created_at, updated_at
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_ar_internal_metadata_insert_result
      sql = "INSERT INTO `ar_internal_metadata` (`key`, `value`, `created_at`, `updated_at`) VALUES (@key_1, @value_2, @created_at_3, @updated_at_4)"
      @mock.put_statement_result sql, StatementResult.new(1)
    end

    def register_empty_select_tables_result(sql)
      table_catalog = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_CATALOG", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      table_schema = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_SCHEMA", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      parent_table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      on_delete_action = Google::Cloud::Spanner::V1::StructType::Field.new name: "ON_DELETE_ACTION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push table_catalog, table_schema, table_name, parent_table_name, on_delete_action
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_single_select_tables_result sql, table_name, parent_table_name = nil, on_delete_action = nil
      col_table_catalog = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_CATALOG", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_table_schema = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_SCHEMA", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_parent_table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_on_delete_action = Google::Cloud::Spanner::V1::StructType::Field.new name: "ON_DELETE_ACTION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_table_catalog, col_table_schema, col_table_name, col_parent_table_name, col_on_delete_action
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: ""),
        Google::Protobuf::Value.new(string_value: ""),
        Google::Protobuf::Value.new(string_value: table_name)
      )
      if parent_table_name
        row.values.push(
          Google::Protobuf::Value.new(string_value: parent_table_name),
          Google::Protobuf::Value.new(string_value: on_delete_action)
        )
      else
        row.values.push(
          Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
          Google::Protobuf::Value.new(null_value: "NULL_VALUE")
        )
      end
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_empty_select_indexes_result sql
      col_index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_index_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_is_unique = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_UNIQUE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BOOL)
      col_is_null_filtered = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULL_FILTERED", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BOOL)
      col_parent_table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_index_state = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_STATE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_index_name, col_index_type, col_is_unique, col_is_null_filtered, col_parent_table_name, col_index_state
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_empty_select_index_columns_result sql
      col_index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column_ordering = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_ORDERING", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_index_name, col_column_name, col_column_ordering, col_ordinal_position
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_version_result(from_version, to_version)
      sql = "SELECT `schema_migrations`.`version` FROM `schema_migrations` ORDER BY `schema_migrations`.`version` ASC"

      version_column = Google::Cloud::Spanner::V1::StructType::Field.new name: "version", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push version_column
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      if from_version
        (from_version...to_version).each { |version|
          row = Google::Protobuf::ListValue.new
          row.values.push Google::Protobuf::Value.new(string_value: version.to_s)
          result_set.rows.push row
        }
      end
      @mock.put_statement_result sql, StatementResult.new(result_set)

      update_sql = "INSERT INTO `schema_migrations` (`version`) VALUES (@version_1)"
      @mock.put_statement_result update_sql, StatementResult.new(1)
    end
  end
end
