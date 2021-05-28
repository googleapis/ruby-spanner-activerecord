# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"
require_relative "models/singer"
require_relative "models/album"

require "securerandom"

class SpannerActiveRecordMockServerTest < Minitest::Test
  def setup
    super
    @server = GRPC::RpcServer.new
    @port = @server.add_http2_port "localhost:0", :this_port_is_insecure
    @mock = SpannerMockServer.new
    @server.handle(@mock)
    # Run the server in a separate thread
    @server_thread = Thread.new do
      @server.run
    end
    # Register INFORMATION_SCHEMA queries on the mock server.
    register_select_tables_result
    register_singers_columns_result
    register_singers_primary_key_result
    register_singer_index_columns_result
    # Connect ActiveRecord to the mock server
    ActiveRecord::Base.establish_connection(
      adapter: "spanner",
      emulator_host: "localhost:#{@port}",
      project: "test-project",
      instance: "test-instance",
      database: "testdb"
    )
    ActiveRecord::Base.logger = nil
  end

  def teardown
    super
    ActiveRecord::Base.connection_pool.disconnect!
    @server.stop
    @server_thread.exit
  end

  def test_selects_all_singers_without_transaction
    sql = "SELECT `singers`.* FROM `singers`"
    @mock.put_statement_result sql, create_random_singers_result(4)
    Singer.all.each do |singer|
      assert singer.id != nil
      assert singer.first_name != nil
      assert singer.last_name != nil
    end
    # None of the requests should use a (read-only) transaction.
    select_requests = @mock.requests.select { |req| req.is_a? V1::ExecuteSqlRequest }
    select_requests.each do |request|
      assert_nil request.transaction
    end
    # Executing a simple query should not initiate any transactions.
    begin_transaction_requests = @mock.requests.select { |req| req.is_a? V1::BeginTransactionRequest }
    assert_empty begin_transaction_requests
  end

  def test_selects_one_singer_without_transaction
    sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = 1 LIMIT 1"
    @mock.put_statement_result sql, create_random_singers_result(1)
    singer = Singer.find_by id: 1

    refute_nil singer
    refute_nil singer.first_name
    refute_nil singer.last_name
    # None of the requests should use a (read-only) transaction.
    select_requests = @mock.requests.select { |req| req.is_a? V1::ExecuteSqlRequest }
    select_requests.each do |request|
      assert_nil request.transaction
    end
    # Executing a simple query should not initiate any transactions.
    begin_transaction_requests = @mock.requests.select { |req| req.is_a? V1::BeginTransactionRequest }
    assert_empty begin_transaction_requests
  end

  def test_update_one_singer_should_use_transaction
    # Preferably, this use case should use mutations instead of DML, as single updates
    # using DML are a lot slower than using mutations. Mutations can however not be
    # read back during a transaction (no read-your-writes), but that is not needed in
    # this case as the application is not managing the transaction itself.
    select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = 1 LIMIT 1"
    @mock.put_statement_result select_sql, create_random_singers_result(1)

    singer = Singer.find_by id: 1

    update_sql = "UPDATE `singers` SET `first_name` = 'Dave' WHERE `singers`.`id` = #{singer.id}"
    @mock.put_statement_result update_sql, StatementResult.new(1)

    singer.first_name = 'Dave'
    singer.save!

    begin_transaction_requests = @mock.requests.select { |req| req.is_a? V1::BeginTransactionRequest }
    assert_equal 1, begin_transaction_requests.length
  end

  def test_update_two_singers_should_use_transaction
    select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` BETWEEN 1 AND 2"
    @mock.put_statement_result select_sql, create_random_singers_result(2)

    ActiveRecord::Base.transaction do
      singers = Singer.where id: 1..2
      @mock.put_statement_result "UPDATE `singers` SET `first_name` = 'Name1' WHERE `singers`.`id` = #{singers[0].id}", StatementResult.new(1)
      @mock.put_statement_result "UPDATE `singers` SET `first_name` = 'Name2' WHERE `singers`.`id` = #{singers[1].id}", StatementResult.new(1)

      singers[0].update! first_name: "Name1"
      singers[1].update! first_name: "Name2"
    end

    begin_transaction_requests = @mock.requests.select { |req| req.is_a? V1::BeginTransactionRequest }
    assert_equal 1, begin_transaction_requests.length
    # All of the requests should use a transaction.
    select_requests = @mock.requests.select { |req| req.is_a?(V1::ExecuteSqlRequest) && (req.sql.starts_with?("SELECT `singers`.*") || req.sql.starts_with?("UPDATE")) }
    select_requests.each do |request|
      refute_nil request.transaction
    end
  end

  def create_random_singers_result(row_count)
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson]
    col_id = V1::StructType::Field.new name: "id", type: V1::Type.new(code: V1::TypeCode::INT64)
    col_first_name = V1::StructType::Field.new name: "first_name", type: V1::Type.new(code: V1::TypeCode::STRING)
    col_last_name = V1::StructType::Field.new name: "last_name", type: V1::Type.new(code: V1::TypeCode::STRING)

    metadata = V1::ResultSetMetadata.new row_type: V1::StructType.new
    metadata.row_type.fields.push col_id, col_first_name, col_last_name
    result_set = V1::ResultSet.new metadata: metadata

    (1..row_count).each { |_|
      row = Protobuf::ListValue.new
      row.values.push(
        Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s),
        Protobuf::Value.new(string_value: first_names.sample),
        Protobuf::Value.new(string_value: last_names.sample)
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def register_select_tables_result
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

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_singers_columns_result
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

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_singers_primary_key_result
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

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end

  def register_singer_index_columns_result
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

    @mock.put_statement_result sql, StatementResult.new(result_set)
  end
end
