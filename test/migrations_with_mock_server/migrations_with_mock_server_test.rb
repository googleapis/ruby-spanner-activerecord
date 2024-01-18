# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "securerandom"

require_relative "../activerecord_spanner_mock_server/model_helper"
require_relative "../test_helper"
require_relative "../mock_server/spanner_mock_server"
require_relative "../mock_server/database_admin_mock_server"
require_relative "models/album"
require_relative "models/singer"
require_relative "models/track"

module TestMigrationsWithMockServer
  Value = Google::Protobuf::Value
  ListValue = Google::Protobuf::ListValue
  Field = Google::Cloud::Spanner::V1::StructType::Field
  Type = Google::Cloud::Spanner::V1::Type
  TypeCode = Google::Cloud::Spanner::V1::TypeCode
  ResultSetMetadata = Google::Cloud::Spanner::V1::ResultSetMetadata
  StructType = Google::Cloud::Spanner::V1::StructType
  ResultSet = Google::Cloud::Spanner::V1::ResultSet

  # Tests executing a simple migration on a mock Spanner server.
  class SpannerMigrationsMockServerTest < Minitest::Test
    VERSION_6_1_0 = Gem::Version.create('6.1.0')
    VERSION_7_1_0 = Gem::Version.create('7.1.0')

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
      register_empty_select_tables_result "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=''"
      register_schema_migrations_table_result
      register_schema_migrations_columns_result
      register_schema_migrations_primary_key_result
      register_ar_internal_metadata_table_result
      register_ar_internal_metadata_columns_result
      register_ar_internal_metadata_primary_key_result
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

    def is_7_1_or_higher?
      ActiveRecord::gem_version >= VERSION_7_1_0
    end

    def with_change_table table_name
      yield ActiveRecord::Base.connection.update_table_definition(table_name, ActiveRecord::Base.connection)
    end

    def migration_context
      if ActiveRecord.gem_version >= Gem::Version.create("7.1.0")
        ActiveRecord::MigrationContext.new(
          "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
        )
      else
        ActiveRecord::MigrationContext.new(
          "#{Dir.pwd}/test/migrations_with_mock_server/db/migrate",
          ActiveRecord::SchemaMigration
        )
      end
    end

    def test_execute_migrations
      context = migration_context

      # Register migration result for the current version (nil) to the new version (1).
      register_version_result nil, "1"

      context.migrate 1

      # The migration should create the migration tables and the singers and albums tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert ddl_requests[0].statements[0].start_with? "CREATE TABLE `schema_migrations`"
      assert_equal 1, ddl_requests[1].statements.length
      assert ddl_requests[1].statements[0].start_with? "CREATE TABLE `ar_internal_metadata`"
      # The actual migration should be executed as one batch.
      assert_equal 5, ddl_requests[2].statements.length
      assert_equal(
        "CREATE TABLE `singers` (`singerid` INT64 NOT NULL, `first_name` STRING(200), `last_name` STRING(MAX)) PRIMARY KEY (`singerid`)",
            ddl_requests[2].statements[0]
      )
      assert ddl_requests[2].statements[1].start_with? "CREATE TABLE `albums`"
      assert ddl_requests[2].statements[2].start_with? "ALTER TABLE `albums` ADD CONSTRAINT"
      assert_equal "ALTER TABLE `singers` ADD COLUMN `place_of_birth` STRING(MAX)", ddl_requests[2].statements[3]
      assert_equal(
        "CREATE TABLE `albums_singers` (`singer_id` INT64 NOT NULL, `album_id` INT64 NOT NULL) PRIMARY KEY (`singer_id`, `album_id`)",
        ddl_requests[2].statements[4]
      )
    end

    def test_execute_migration_without_batching
      context = migration_context

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
      context = migration_context

      register_version_result "1", "3"

      context.migrate 3

      # The migration should create the migration tables and the singers and albums tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      # CREATE TABLE `types_table` (`id` INT64 NOT NULL, `col_string` STRING(MAX), `col_text` STRING(MAX),
      # `col_integer` INT64, `col_bigint` INT64, `col_float` FLOAT64, `col_decimal` FLOAT64, `col_numeric` numeric,
      # `col_datetime` TIMESTAMP, `col_time` TIMESTAMP, `col_date` DATE, `col_binary` BYTES(MAX), `col_boolean` BOOL,
      # `col_json` JSON, `col_array_string` ARRAY<STRING(MAX)>, `col_array_text` ARRAY<STRING(MAX)>,
      # `col_array_integer` ARRAY<INT64>, `col_array_bigint` ARRAY<INT64>, `col_array_float` ARRAY<FLOAT64>,
      # `col_array_decimal` ARRAY<FLOAT64>, `col_array_numeric` ARRAY<NUMERIC>, `col_array_datetime` ARRAY<TIMESTAMP>,
      # `col_array_time` ARRAY<TIMESTAMP>, `col_array_date` ARRAY<DATE>, `col_array_binary` ARRAY<BYTES(MAX)>,
      # `col_array_boolean` ARRAY<BOOL>, `col_array_json` ARRAY<JSON>
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
      expectedDdl << "`col_json` JSON, "
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
      expectedDdl << "`col_array_boolean` ARRAY<BOOL>, "
      expectedDdl << "`col_array_json` ARRAY<JSON>) "
      expectedDdl << "PRIMARY KEY (`id`)"

      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_interleaved_table
      context = migration_context
      select_albums_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_albums_table_sql, "albums", "singers", "NO_ACTION"
      select_albums_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_albumid' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_albums_index_columns_sql
      select_albums_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_albumid' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_albums_indexes_sql

      select_tracks_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='tracks'"
      register_single_select_tables_result select_tracks_table_sql, "tracks", "albums", "NO_ACTION"
      select_tracks_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='tracks' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_tracks_on_trackid' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_tracks_index_columns_sql
      select_tracks_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='tracks' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_tracks_on_trackid' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_tracks_indexes_sql

      register_version_result "1", "4"

      context.migrate 4

      # The migration should create the migration tables and the singers, albums and tracks tables in one request.
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 5, ddl_requests[2].statements.length

      expectedDdl = "CREATE TABLE `singers` "
      expectedDdl << "(`singerid` INT64 NOT NULL, `first_name` STRING(200), `last_name` STRING(MAX)) "
      expectedDdl << "PRIMARY KEY (`singerid`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]

      expectedDdl = "CREATE TABLE `albums` "
      expectedDdl << "(`albumid` INT64 NOT NULL, `singerid` INT64 NOT NULL, `title` STRING(MAX)"
      expectedDdl << ") PRIMARY KEY (`singerid`, `albumid`), INTERLEAVE IN PARENT `singers`"
      assert_equal expectedDdl, ddl_requests[2].statements[1]

      expectedDdl = "CREATE UNIQUE INDEX `index_albums_on_albumid` "
      expectedDdl << "ON `albums` (`albumid`)"
      assert_equal expectedDdl, ddl_requests[2].statements[2]

      expectedDdl = "CREATE TABLE `tracks` "
      expectedDdl << "(`trackid` INT64 NOT NULL, `singerid` INT64 NOT NULL, `albumid` INT64 NOT NULL, `title` STRING(MAX), `duration` NUMERIC"
      if ActiveRecord.gem_version >= Gem::Version.create("6.1.0")
        expectedDdl << ", CONSTRAINT chk_tracks_duration CHECK (duration > 0)"
      end
      expectedDdl << ") PRIMARY KEY (`singerid`, `albumid`, `trackid`), INTERLEAVE IN PARENT `albums` ON DELETE CASCADE"
      assert_equal expectedDdl, ddl_requests[2].statements[3]

      expectedDdl = "CREATE UNIQUE INDEX `index_tracks_on_trackid` "
      expectedDdl << "ON `tracks` (`trackid`)"
      assert_equal expectedDdl, ddl_requests[2].statements[4]
    end

    if ActiveRecord::gem_version < Gem::Version.create('7.1.0')
      def test_interleaved_table_with_uuid_pk
        context = migration_context

        select_albums_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
        register_single_select_tables_result select_albums_table_sql, "albums", "singers", "NO_ACTION"
        select_albums_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_albumid' ORDER BY ORDINAL_POSITION ASC"
        register_empty_select_index_columns_result select_albums_index_columns_sql
        select_albums_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_albumid' AND SPANNER_IS_MANAGED=FALSE"
        MockServerTests::register_empty_select_indexes_result @mock, select_albums_indexes_sql

        select_tracks_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='tracks'"
        register_single_select_tables_result select_tracks_table_sql, "tracks", "albums", "NO_ACTION"
        select_tracks_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='tracks' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_tracks_on_trackid' ORDER BY ORDINAL_POSITION ASC"
        register_empty_select_index_columns_result select_tracks_index_columns_sql
        select_tracks_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='tracks' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_tracks_on_trackid' AND SPANNER_IS_MANAGED=FALSE"
        MockServerTests::register_empty_select_indexes_result @mock, select_tracks_indexes_sql

        register_version_result "1", "10"

        context.migrate 10

        # The migration should create the migration tables and the singers, albums and tracks tables in one request.
        ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
        # The migration simulation also creates the two migration metadata tables.
        assert_equal 3, ddl_requests.length
        assert_equal 2, ddl_requests[2].statements.length

        expectedDdl = "CREATE TABLE `parent_with_uuid_pk` "
        expectedDdl << "(`parentid` STRING(36) NOT NULL, `first_name` STRING(MAX), `last_name` STRING(MAX)) "
        expectedDdl << "PRIMARY KEY (`parentid`)"
        assert_equal expectedDdl, ddl_requests[2].statements[0]

        expectedDdl = "CREATE TABLE `child_with_uuid_pk` "
        expectedDdl << "(`parentid` STRING(36) NOT NULL, `childid` INT64 NOT NULL, `title` STRING(MAX)) "
        expectedDdl << "PRIMARY KEY (`parentid`, `childid`), INTERLEAVE IN PARENT `parent_with_uuid_pk`"
        assert_equal expectedDdl, ddl_requests[2].statements[1]
      end
    end

    def test_create_table_with_commit_timestamp
      context = migration_context

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
      context = migration_context

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

    def test_add_column
      with_change_table :singers do |t|
        t.column :age, :integer
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `age` INT64", ddl_requests[0].statements[0]
    end

    def test_drop_column
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql
      select_fk_sql = foreign_keys_sql "singers"
      register_empty_select_foreign_key_result select_fk_sql

      with_change_table :singers do |t|
        t.remove :age
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` DROP COLUMN `age`", ddl_requests[0].statements[0]
    end

    def test_change_column
      MockServerTests::register_singers_primary_key_columns_result @mock unless is_7_1_or_higher?
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock if is_7_1_or_higher?
      select_column_sql = MockServerTests.table_columns_sql "singers", column_name: "age"
      register_select_single_column_result select_column_sql, "age", "INT64"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql

      with_change_table :singers do |t|
        t.change :age, :decimal
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ALTER COLUMN `age` NUMERIC", ddl_requests[0].statements[0]
    end

    def test_change_column_add_not_null
      MockServerTests::register_singers_primary_key_columns_result @mock unless is_7_1_or_higher?
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock if is_7_1_or_higher?

      select_column_sql = MockServerTests.table_columns_sql "singers", column_name: "age"
      register_select_single_column_result select_column_sql, "age", "INT64"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql

      with_change_table :singers do |t|
        t.change :age, :integer, **{null: false}
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ALTER COLUMN `age` INT64 NOT NULL", ddl_requests[0].statements[0]
    end

    def test_change_column_remove_not_null
      MockServerTests::register_singers_primary_key_columns_result @mock unless is_7_1_or_higher?
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock if is_7_1_or_higher?
      select_column_sql = MockServerTests.table_columns_sql "singers", column_name: "age"
      register_select_single_column_result select_column_sql, "age", "INT64"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql

      with_change_table :singers do |t|
        t.change :age, :integer, **{null: true}
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ALTER COLUMN `age` INT64", ddl_requests[0].statements[0]
    end

    def test_rename_column
      MockServerTests::register_singers_primary_key_columns_result @mock unless is_7_1_or_higher?
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock if is_7_1_or_higher?
      # Cloud Spanner does not support renaming a column, so instead the migration will create a new column, copy the
      # data from the old column to the new column, and then drop the old column.
      select_column_sql = MockServerTests.table_columns_sql "singers", column_name: "age"
      register_select_single_column_result select_column_sql, "age", "INT64"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql
      select_fk_sql = foreign_keys_sql "singers"
      register_empty_select_foreign_key_result select_fk_sql
      update_data_sql = "UPDATE singers SET `age_at_insert` = `age` WHERE true"
      @mock.put_statement_result update_data_sql, StatementResult.new(100)

      # Note: Renaming a column in a DDL batch is not supported, as it involves copying data from one column to another.
      with_change_table :singers do |t|
        t.rename :age, :age_at_insert
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 2, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal 1, ddl_requests[1].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `age_at_insert` INT64", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` DROP COLUMN `age`", ddl_requests[1].statements[0]
      update_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_data_sql }
      assert_equal 1, update_requests.length
    end

    def test_interleaved_index
      context = migration_context
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_table_sql, "albums", "singers", "NO_ACTION"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singerid_and_title' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singerid_and_title' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql
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
      context = migration_context
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_picture' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_picture' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql
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
      context = migration_context
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_full_name' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_full_name' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_indexes_sql
      register_version_result "1", "9"

      context.migrate 9

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE INDEX `index_singers_on_full_name` ON `singers` (`full_name`) STORING (`first_name`, `last_name`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_references_column_type_adds_column_and_index
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_table_sql, "albums"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_column_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_column_sql

      [:references, :belongs_to].each do |method|
        ActiveRecord::Base.connection.ddl_batch do
          with_change_table :albums do |t|
            t.method(method).call :singer
          end
        end

        ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
        assert_equal 1, ddl_requests.length
        assert_equal 2, ddl_requests[0].statements.length
        assert_equal "ALTER TABLE `albums` ADD COLUMN `singer_id` INT64", ddl_requests[0].statements[0]
        # ActiveRecord by default does not create a FOREIGN KEY CONSTRAINT when it creates a reference.
        assert_equal "CREATE INDEX `index_albums_on_singer_id` ON `albums` (`singer_id`)", ddl_requests[0].statements[1]
        @database_admin_mock.requests.clear
      end
    end

    def test_references_column_adds_foreign_key_and_no_index
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_table_sql, "albums"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_column_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_column_sql

      [:references, :belongs_to].each do |method|
        ActiveRecord::Base.connection.ddl_batch do
          with_change_table :albums do |t|
            # The `index: true` below will be ignored by the Spanner adapter, because Cloud Spanner automatically creates
            # a managed index for a foreign key. Creating an additional non-managed index would only cause additional
            # writes and no performance gain.
            t.method(method).call :singer, foreign_key: true, index: true
          end
        end

        ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
        assert_equal 1, ddl_requests.length
        assert_equal 2, ddl_requests[0].statements.length
        assert_equal "ALTER TABLE `albums` ADD COLUMN `singer_id` INT64", ddl_requests[0].statements[0]
        fk_def = "ALTER TABLE `albums` ADD CONSTRAINT `fk_rails_df791b93c8`\n"
        fk_def << "FOREIGN KEY (`singer_id`)\n"
        fk_def << "  REFERENCES `singers` (`id`)\n"
        assert_equal fk_def, ddl_requests[0].statements[1]
        @database_admin_mock.requests.clear
      end
    end

    def test_remove_references_column_removes_index_and_column
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_table_sql, "albums"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' AND SPANNER_IS_MANAGED=FALSE"
      register_single_select_indexes_result select_index_sql, "index_albums_on_singer_id"
      select_all_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      register_single_select_indexes_result select_all_indexes_sql, "index_albums_on_singer_id"
      select_index_column_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' ORDER BY ORDINAL_POSITION ASC"
      register_single_select_index_columns_result select_index_column_sql, "index_albums_on_singer_id", "singer_id"
      select_all_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_single_select_index_columns_result select_all_index_columns_sql, "index_albums_on_singer_id", "singer_id"
      select_fk_sql = foreign_keys_sql "albums"
      register_empty_select_foreign_key_result select_fk_sql

      [:remove_references, :remove_belongs_to].each do |method|
        ActiveRecord::Base.connection.ddl_batch do
          with_change_table :albums do |t|
            t.method(method).call :singer
          end
        end

        # The migration should first drop the index on the column and then drop the column.
        ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
        assert_equal 1, ddl_requests.length
        assert_equal 2, ddl_requests[0].statements.length
        assert_equal "DROP INDEX `index_albums_on_singer_id`", ddl_requests[0].statements[0]
        assert_equal "ALTER TABLE `albums` DROP COLUMN `singer_id`", ddl_requests[0].statements[1]
        @database_admin_mock.requests.clear
      end
    end

    def test_remove_references_column_removes_foreign_key_and_column
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='albums'"
      register_single_select_tables_result select_table_sql, "albums"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_all_indexes_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_all_indexes_sql
      select_index_column_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_albums_on_singer_id' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_column_sql
      select_all_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='albums' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_all_index_columns_sql
      select_fk_sql = foreign_keys_sql "albums"
      register_single_select_foreign_key_result select_fk_sql, "albums", "singers", "singer_id", "singer_id", "fk_albums_singer"

      [:remove_references, :remove_belongs_to].each do |method|
        ActiveRecord::Base.connection.ddl_batch do
          with_change_table :albums do |t|
            t.method(method).call :singer
          end
        end

        # The migration should first drop the index on the column and then drop the column.
        ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
        assert_equal 1, ddl_requests.length
        assert_equal 2, ddl_requests[0].statements.length
        assert_equal "ALTER TABLE `albums` DROP CONSTRAINT `fk_albums_singer`", ddl_requests[0].statements[0]
        assert_equal "ALTER TABLE `albums` DROP COLUMN `singer_id`", ddl_requests[0].statements[1]
        @database_admin_mock.requests.clear
      end
    end

    def test_references_column_with_polymorphic_adds_type
      index_name = ActiveRecord::gem_version < VERSION_6_1_0 \
                     ? "index_singers_on_person_type_and_person_id"
                     : "index_singers_on_person"

      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "albums"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='#{index_name}' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_column_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='#{index_name}' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_column_sql

      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.references :person, polymorphic: true
        end
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 3, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `person_type` STRING(255)", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` ADD COLUMN `person_id` INT64", ddl_requests[0].statements[1]
      assert_equal "CREATE INDEX `#{index_name}` ON `singers` (`person_type`, `person_id`)", ddl_requests[0].statements[2]
    end

    def test_references_column_with_polymorphic_and_foreign_key_fails
      err = assert_raises do
        with_change_table :singers do |t|
          t.references :person, polymorphic: true, foreign_key: true
        end
      end
      assert err&.message&.include? "Cannot add a foreign key to a polymorphic relation"
    end

    def test_integer_creates_integer_column
      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.integer :foo, :bar
        end
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 2, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `foo` INT64", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` ADD COLUMN `bar` INT64", ddl_requests[0].statements[1]
    end

    def test_bigint_creates_integer_column
      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.bigint :foo, :bar
        end
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 2, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `foo` INT64", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` ADD COLUMN `bar` INT64", ddl_requests[0].statements[1]
    end

    def test_string_creates_string_column
      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.string :foo, :bar
        end
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 2, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `foo` STRING(MAX)", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` ADD COLUMN `bar` STRING(MAX)", ddl_requests[0].statements[1]
    end

    def test_drop_index
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_TYPE='INDEX' AND SPANNER_IS_MANAGED=FALSE"
      register_single_select_indexes_result select_index_sql, "full_name-index"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_single_select_index_columns_result select_index_columns_sql, "full_name-index", "full_name"

      with_change_table :singers do |t|
        t.remove_index :full_name
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length

      expectedDdl = "DROP INDEX `full_name-index`"
      assert_equal expectedDdl, ddl_requests[0].statements[0]
    end

    def test_drop_index_with_name
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_TYPE='INDEX' AND SPANNER_IS_MANAGED=FALSE"
      register_single_select_indexes_result select_index_sql, "some-index"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_single_select_index_columns_result select_index_columns_sql, "some-index", "some-column"

      with_change_table :singers do |t|
        t.remove_index name: "some-index"
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length

      expectedDdl = "DROP INDEX `some-index`"
      assert_equal expectedDdl, ddl_requests[0].statements[0]
    end

    def test_column_creates_column
      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.column :age, :integer
        end
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `age` INT64", ddl_requests[0].statements[0]
    end

    def test_column_creates_column_with_options
      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.column :age, :integer, null: false
        end
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      # Note that Cloud Spanner does currently not support adding a NOT NULL column to an existing table. It does
      # however allow altering an existing column to from nullable to NOT NULL. This migration therefore generates two
      # commands.
      assert_equal 2, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ADD COLUMN `age` INT64", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` ALTER COLUMN `age` INT64 NOT NULL", ddl_requests[0].statements[1]
    end

    def test_column_creates_column_with_index
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_age' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_age' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql

      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.column :age, :integer, index: true
        end
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 2, ddl_requests[0].statements.length

      assert_equal "ALTER TABLE `singers` ADD COLUMN `age` INT64", ddl_requests[0].statements[0]
      assert_equal "CREATE INDEX `index_singers_on_age` ON `singers` (`age`)", ddl_requests[0].statements[1]
    end

    def test_index_creates_index
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_age' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_age' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql

      with_change_table :singers do |t|
        t.index :age
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "CREATE INDEX `index_singers_on_age` ON `singers` (`age`)", ddl_requests[0].statements[0]
    end

    def test_index_creates_index_with_options
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_age' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_singers_on_age' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql

      with_change_table :singers do |t|
        t.index :age, unique: true
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "CREATE UNIQUE INDEX `index_singers_on_age` ON `singers` (`age`)", ddl_requests[0].statements[0]
    end

    def test_rename_index_renames_index
      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_full_name' AND SPANNER_IS_MANAGED=FALSE"
      register_single_select_indexes_result select_index_sql, "index_full_name"
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='index_full_name' ORDER BY ORDINAL_POSITION ASC"
      register_single_select_index_columns_result select_index_columns_sql, "index_full_name", "full_name"

      ActiveRecord::Base.connection.ddl_batch do
        with_change_table :singers do |t|
          t.rename_index :index_full_name, :index_singers_full_name
        end
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 2, ddl_requests[0].statements.length
      # Cloud Spanner does not support renaming an index, so the index is dropped and recreated.
      assert_equal "DROP INDEX `index_full_name`", ddl_requests[0].statements[0]
      assert_equal "CREATE INDEX `index_singers_full_name` ON `singers` (`full_name`)", ddl_requests[0].statements[1]
    end

    def test_remove_drops_single_column
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_fk_sql = foreign_keys_sql "singers"
      register_empty_select_foreign_key_result select_fk_sql

      with_change_table :singers do |t|
        t.remove :age
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` DROP COLUMN `age`", ddl_requests[0].statements[0]
    end

    def test_remove_drops_multiple_columns
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql
      select_fk_sql = foreign_keys_sql "singers"
      register_empty_select_foreign_key_result select_fk_sql
      with_change_table :singers do |t|
        t.remove :age, :full_name
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 2, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` DROP COLUMN `age`", ddl_requests[0].statements[0]
      assert_equal "ALTER TABLE `singers` DROP COLUMN `full_name`", ddl_requests[0].statements[1]
    end

    def test_change_changes_column
      MockServerTests::register_singers_primary_key_columns_result @mock unless is_7_1_or_higher?
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock if is_7_1_or_higher?
      select_column_sql = MockServerTests.table_columns_sql "singers", column_name: "picture"
      register_single_select_columns_result select_column_sql, "picture", "BYTES(MAX)"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql

      with_change_table :singers do |t|
        t.change :picture, :string
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ALTER COLUMN `picture` STRING(MAX)", ddl_requests[0].statements[0]
    end

    def test_change_changes_column_with_options
      MockServerTests::register_singers_primary_key_columns_result @mock unless is_7_1_or_higher?
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock if is_7_1_or_higher?
      select_column_sql = MockServerTests.table_columns_sql "singers", column_name: "picture"
      register_single_select_columns_result select_column_sql, "picture", "BYTES(MAX)"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql

      with_change_table :singers do |t|
        t.change :picture, :string, null: false
      end
      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "ALTER TABLE `singers` ALTER COLUMN `picture` STRING(MAX) NOT NULL", ddl_requests[0].statements[0]
    end

    def test_change_default_not_supported
      err = assert_raises do
        with_change_table :singers do |t|
          t.change_default :picture, :binary
        end
      end
      assert err.is_a? ActiveRecordSpannerAdapter::NotSupportedError
    end

    def test_creates_polymorphic_index_for_existing_table
      index_name = "index_singers_on_foo" unless ActiveRecord::gem_version < Gem::Version.create('6.1.0')
      index_name = "index_singers_on_foo_type_and_foo_id" if ActiveRecord::gem_version < Gem::Version.create('6.1.0')

      select_table_sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='singers'"
      register_single_select_tables_result select_table_sql, "singers"
      select_index_sql = "SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE FROM INFORMATION_SCHEMA.INDEXES WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='#{index_name}' AND SPANNER_IS_MANAGED=FALSE"
      MockServerTests::register_empty_select_indexes_result @mock, select_index_sql
      select_index_columns_sql = "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION FROM INFORMATION_SCHEMA.INDEX_COLUMNS WHERE TABLE_NAME='singers' AND TABLE_CATALOG = '' AND TABLE_SCHEMA = '' AND INDEX_NAME='#{index_name}' ORDER BY ORDINAL_POSITION ASC"
      register_empty_select_index_columns_result select_index_columns_sql

      ActiveRecord::Base.connection.change_table :singers do |t|
        t.references :foo, polymorphic: true, index: true
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE INDEX `#{index_name}` ON `singers` (`foo_type`, `foo_id`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_create_table_with_default_value
      context = migration_context

      register_version_result "1", "11"

      context.migrate 11

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 1, ddl_requests[2].statements.length

      expectedDdl = "CREATE TABLE `singers` "
      expectedDdl << "(`id` INT64 NOT NULL, `name` STRING(MAX) NOT NULL DEFAULT ('no name'), `age` INT64 NOT NULL DEFAULT (0)) "
      expectedDdl << "PRIMARY KEY (`id`)"
      assert_equal expectedDdl, ddl_requests[2].statements[0]
    end

    def test_create_join_table_with_column_options
      MockServerTests::register_join_table_primary_key_result @mock if is_7_1_or_higher?
      MockServerTests::register_join_table_key_columns_result @mock, "artists_musics", "artist_id", "music_id"
      MockServerTests::register_join_table_columns_result @mock, "artists_musics", "artist_id", "music_id"

      connection = ActiveRecord::Base.connection
      connection.ddl_batch do
        connection.create_join_table :artists, :musics, column_options: { null: true }
      end

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      assert_equal 1, ddl_requests.length
      assert_equal 1, ddl_requests[0].statements.length
      assert_equal "CREATE TABLE `artists_musics` (`artist_id` INT64, `music_id` INT64) PRIMARY KEY (`artist_id`, `music_id`)",
                   ddl_requests[0].statements[0]

      assert_equal [true, true], connection.columns(:artists_musics).map(&:null)
    end

    def test_create_table_with_sequence
      context = migration_context

      register_version_result "1", "12"

      context.migrate 12

      ddl_requests = @database_admin_mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::Admin::Database::V1::UpdateDatabaseDdlRequest) }
      # The migration simulation also creates the two migration metadata tables.
      assert_equal 3, ddl_requests.length
      assert_equal 2, ddl_requests[2].statements.length

      assert_equal "create sequence test_sequence OPTIONS (sequence_kind = 'bit_reversed_positive')", ddl_requests[2].statements[0]
      expectedDdl = "CREATE TABLE `table_with_sequence` "
      expectedDdl << "(`id` INT64 NOT NULL DEFAULT (GET_NEXT_SEQUENCE_VALUE(SEQUENCE test_sequence)), `name` STRING(MAX) NOT NULL, `age` INT64 NOT NULL) "
      expectedDdl << "PRIMARY KEY (`id`)"
      assert_equal expectedDdl, ddl_requests[2].statements[1]
    end

    def register_schema_migrations_table_result
      sql = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='' AND TABLE_NAME='schema_migrations'"
      register_empty_select_tables_result sql
    end

    def register_schema_migrations_columns_result
      # CREATE TABLE `schema_migrations` (`version` STRING(MAX) NOT NULL) PRIMARY KEY (`version`)
      MockServerTests::register_commit_timestamps_result @mock, "schema_migrations"

      sql = MockServerTests.table_columns_sql "schema_migrations"

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
        Google::Protobuf::Value.new(string_value: "version"),
        Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "1")
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_schema_migrations_primary_key_result
      sql = MockServerTests.primary_key_columns_sql "schema_migrations", parent_keys: false

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
        Google::Protobuf::Value.new(string_value: "version"),
        Google::Protobuf::Value.new(string_value: "ASC"),
        Google::Protobuf::Value.new(string_value: "1"),
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
      MockServerTests::register_commit_timestamps_result @mock, "ar_internal_metadata"

      sql = MockServerTests.table_columns_sql "ar_internal_metadata"

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
        Google::Protobuf::Value.new(string_value: "key"),
        Google::Protobuf::Value.new(string_value: "STRING(MAX)"),
        Google::Protobuf::Value.new(string_value: "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
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
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "4")
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_ar_internal_metadata_primary_key_result
      sql = MockServerTests.primary_key_columns_sql "ar_internal_metadata", parent_keys: false

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
        Google::Protobuf::Value.new(string_value: "key"),
        Google::Protobuf::Value.new(string_value: "ASC"),
        Google::Protobuf::Value.new(string_value: "1"),
        )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_ar_internal_metadata_results
      # CREATE TABLE `ar_internal_metadata` (`key` STRING(MAX) NOT NULL, `value` STRING(MAX), `created_at` TIMESTAMP NOT NULL, `updated_at` TIMESTAMP NOT NULL) PRIMARY KEY (`key`)
      sql = ActiveRecord::gem_version < VERSION_7_1_0 \
          ? "SELECT `ar_internal_metadata`.* FROM `ar_internal_metadata` WHERE `ar_internal_metadata`.`key` = @p1 LIMIT @p2"
          : "SELECT * FROM `ar_internal_metadata` WHERE `ar_internal_metadata`.`key` = @p1 ORDER BY `ar_internal_metadata`.`key` ASC LIMIT 1"

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
      sql = ActiveRecord::gem_version < VERSION_7_1_0 \
          ? "INSERT INTO `ar_internal_metadata` (`key`, `value`, `created_at`, `updated_at`) VALUES (@p1, @p2, @p3, @p4)"
          : "INSERT INTO `ar_internal_metadata` (`key`, `value`, `created_at`, `updated_at`) VALUES ('environment', 'default_env', %"
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

    def register_single_select_columns_result sql, column_name, spanner_type, is_nullable = true
      MockServerTests::register_commit_timestamps_result @mock, "singers", column_name
      col_column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_generation_expression = Google::Cloud::Spanner::V1::StructType::Field.new name: "GENERATION_EXPRESSION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_column_name, col_spanner_type, col_is_nullable, col_generation_expression, col_column_default, col_ordinal_position
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: column_name),
        Google::Protobuf::Value.new(string_value: spanner_type),
        Google::Protobuf::Value.new(string_value: is_nullable ? "YES" : "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "1")
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_single_select_indexes_result sql, index_name
      col_index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_index_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_is_unique = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_UNIQUE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BOOL)
      col_is_null_filtered = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULL_FILTERED", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BOOL)
      col_parent_table_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "PARENT_TABLE_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_index_state = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_STATE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_index_name, col_index_type, col_is_unique, col_is_null_filtered, col_parent_table_name, col_index_state
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: index_name),
        Google::Protobuf::Value.new(string_value: "INDEX"),
        Google::Protobuf::Value.new(bool_value: false),
        Google::Protobuf::Value.new(bool_value: false),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "READ_WRITE"),
      )
      result_set.rows.push row

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

    def register_single_select_index_columns_result sql, index_name, column_name
      col_index_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "INDEX_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column_ordering = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_ORDERING", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_index_name, col_column_name, col_column_ordering, col_ordinal_position
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: index_name),
        Google::Protobuf::Value.new(string_value: column_name),
        Google::Protobuf::Value.new(string_value: "ASC"),
        Google::Protobuf::Value.new(string_value: "1"),
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_select_single_column_result sql, column_name, spanner_type, is_nullable = true
      MockServerTests::register_commit_timestamps_result @mock, "singers", column_name
      # "SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE, GENERATION_EXPRESSION, CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='singers' AND COLUMN_NAME='age' ORDER BY ORDINAL_POSITION ASC"
      col_column_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_NAME", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_spanner_type = Google::Cloud::Spanner::V1::StructType::Field.new name: "SPANNER_TYPE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_is_nullable = Google::Cloud::Spanner::V1::StructType::Field.new name: "IS_NULLABLE", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_generation_expression = Google::Cloud::Spanner::V1::StructType::Field.new name: "GENERATION_EXPRESSION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column_default = Google::Cloud::Spanner::V1::StructType::Field.new name: "COLUMN_DEFAULT", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_ordinal_position = Google::Cloud::Spanner::V1::StructType::Field.new name: "ORDINAL_POSITION", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_column_name, col_spanner_type, col_is_nullable, col_generation_expression, col_column_default, col_ordinal_position
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata
      row = Google::Protobuf::ListValue.new
      row.values.push(
        Google::Protobuf::Value.new(string_value: column_name),
        Google::Protobuf::Value.new(string_value: spanner_type),
        Google::Protobuf::Value.new(string_value: is_nullable ? "YES" : "NO"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: ""),
        Google::Protobuf::Value.new(string_value: "1")
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_empty_select_foreign_key_result sql
      col_to_table = Google::Cloud::Spanner::V1::StructType::Field.new name: "to_table", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_primary_key = Google::Cloud::Spanner::V1::StructType::Field.new name: "primary_key", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_column = Google::Cloud::Spanner::V1::StructType::Field.new name: "column", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_name = Google::Cloud::Spanner::V1::StructType::Field.new name: "name", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_on_update = Google::Cloud::Spanner::V1::StructType::Field.new name: "on_update", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
      col_on_delete = Google::Cloud::Spanner::V1::StructType::Field.new name: "on_delete", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col_to_table, col_primary_key, col_column, col_name, col_on_update, col_on_delete
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    def register_single_select_foreign_key_result sql, from_table, to_table, pk_column_name, fk_column_name, constraint_name
      col_constraint_catalog = Field.new name: "CONSTRAINT_CATALOG", type: Type.new(code: TypeCode::STRING)
      col_constraint_schema = Field.new name: "CONSTRAINT_SCHEMA", type: Type.new(code: TypeCode::STRING)
      col_constraint_name = Field.new name: "CONSTRAINT_NAME", type: Type.new(code: TypeCode::STRING)
      col_update_rule = Field.new name: "UPDATE_RULE", type: Type.new(code: TypeCode::STRING)
      col_delete_rule = Field.new name: "DELETE_RULE", type: Type.new(code: TypeCode::STRING)
      col_fk_catalog = Field.new name: "FK_CATALOG", type: Type.new(code: TypeCode::STRING)
      col_fk_schema = Field.new name: "FK_SCHEMA", type: Type.new(code: TypeCode::STRING)
      col_fk_table = Field.new name: "FK_TABLE", type: Type.new(code: TypeCode::STRING)
      col_pk_catalog = Field.new name: "PK_CATALOG", type: Type.new(code: TypeCode::STRING)
      col_pk_schema = Field.new name: "PK_SCHEMA", type: Type.new(code: TypeCode::STRING)
      col_pk_table = Field.new name: "PK_TABLE", type: Type.new(code: TypeCode::STRING)
      col_fk_columns = Field.new name: "FK_COLUMNS",
                                 type: Type.new(code: TypeCode::ARRAY,
                                                array_element_type: Type.new(code: TypeCode::STRING))
      col_pk_columns = Field.new name: "PK_COLUMNS",
                                 type: Type.new(code: TypeCode::ARRAY,
                                                array_element_type: Type.new(code: TypeCode::STRING))

      metadata = ResultSetMetadata.new row_type: StructType.new
      metadata.row_type.fields.push col_constraint_catalog, col_constraint_schema, col_constraint_name,
                                    col_update_rule, col_delete_rule,
                                    col_fk_catalog, col_fk_schema, col_fk_table,
                                    col_pk_catalog, col_pk_schema, col_pk_table,
                                    col_fk_columns, col_pk_columns
      result_set = ResultSet.new metadata: metadata

      pk_column_names = ListValue.new
      pk_column_names.values.push(Value.new(string_value: pk_column_name))
      fk_column_names = ListValue.new
      fk_column_names.values.push(Value.new(string_value: fk_column_name))

      row = ListValue.new
      row.values.push(
        Value.new(string_value: ""), # constraint_catalog
        Value.new(string_value: ""), # constraint_schema
        Value.new(string_value: constraint_name), # constraint_name
        Value.new(string_value: "NO_ACTION"),
        Value.new(string_value: "NO_ACTION"),
        Value.new(string_value: ""), # fk_catalog
        Value.new(string_value: ""), # fk_schema
        Value.new(string_value: from_table), # fk_table
        Value.new(string_value: ""), # pk_catalog
        Value.new(string_value: ""), # pk_schema
        Value.new(string_value: to_table), # pk_table
        Value.new(list_value: fk_column_names),
        Value.new(list_value: fk_column_names),
      )
      result_set.rows.push row

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

      update_sql = ActiveRecord::gem_version < VERSION_7_1_0 \
          ? "INSERT INTO `schema_migrations` (`version`) VALUES (@p1)"
          : "INSERT INTO `schema_migrations` (`version`) VALUES ('%"
      @mock.put_statement_result update_sql, StatementResult.new(1)
    end

    def foreign_keys_sql table_name
      sql = <<~SQL
        SELECT CONSTRAINT_CATALOG, CONSTRAINT_SCHEMA, CONSTRAINT_NAME, UPDATE_RULE, DELETE_RULE,
               FK_CATALOG, FK_SCHEMA, FK_TABLE,
               PK_CATALOG, PK_SCHEMA, PK_TABLE,
               ARRAY_AGG(FK_COLUMN) AS FK_COLUMNS, ARRAY_AGG(PK_COLUMN) AS PK_COLUMNS
        FROM (SELECT CONSTRAINTS.CONSTRAINT_CATALOG,
                     CONSTRAINTS.CONSTRAINT_SCHEMA,
                     CONSTRAINTS.CONSTRAINT_NAME,
                     CONSTRAINTS.UPDATE_RULE,
                     CONSTRAINTS.DELETE_RULE,
                     CHILD.TABLE_CATALOG  AS FK_CATALOG,
                     CHILD.TABLE_SCHEMA   AS FK_SCHEMA,
                     CHILD.TABLE_NAME     AS FK_TABLE,
                     CHILD.COLUMN_NAME    AS FK_COLUMN,
                     PARENT.TABLE_CATALOG AS PK_CATALOG,
                     PARENT.TABLE_SCHEMA  AS PK_SCHEMA,
                     PARENT.TABLE_NAME    AS PK_TABLE,
                     PARENT.COLUMN_NAME   AS PK_COLUMN
              FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS CONSTRAINTS
                       INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CHILD
                                  ON CONSTRAINTS.CONSTRAINT_CATALOG = CHILD.CONSTRAINT_CATALOG
                                      AND CONSTRAINTS.CONSTRAINT_SCHEMA = CHILD.CONSTRAINT_SCHEMA
                                      AND CONSTRAINTS.CONSTRAINT_NAME = CHILD.CONSTRAINT_NAME
                       INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE PARENT
                                  ON CONSTRAINTS.UNIQUE_CONSTRAINT_CATALOG = PARENT.CONSTRAINT_CATALOG
                                      AND CONSTRAINTS.UNIQUE_CONSTRAINT_SCHEMA = PARENT.CONSTRAINT_SCHEMA
                                      AND CONSTRAINTS.UNIQUE_CONSTRAINT_NAME = PARENT.CONSTRAINT_NAME
                                      AND PARENT.ORDINAL_POSITION = CHILD.POSITION_IN_UNIQUE_CONSTRAINT
              ORDER BY CHILD.TABLE_CATALOG, CHILD.TABLE_SCHEMA, CHILD.TABLE_NAME, CHILD.POSITION_IN_UNIQUE_CONSTRAINT
        ) FOREIGN_KEYS
        WHERE FK_TABLE = '%<table_name>s'
          AND FK_SCHEMA = ''
        GROUP BY CONSTRAINT_CATALOG, CONSTRAINT_SCHEMA, CONSTRAINT_NAME, UPDATE_RULE, DELETE_RULE,
                 FK_CATALOG, FK_SCHEMA, FK_TABLE,
                 PK_CATALOG, PK_SCHEMA, PK_TABLE
      SQL
      sql % { table_name: table_name }
    end
  end
end
