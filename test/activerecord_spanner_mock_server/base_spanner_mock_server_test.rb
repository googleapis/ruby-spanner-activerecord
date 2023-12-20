# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./model_helper"
require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"
require_relative "models/singer"
require_relative "models/album"
require_relative "models/all_types"
require_relative "models/table_with_commit_timestamp"
require_relative "models/table_with_sequence"
require_relative "models/versioned_singer"

require "securerandom"

module MockServerTests
  class BaseSpannerMockServerTest < Minitest::Test
    def setup
      super
      @server = GRPC::RpcServer.new
      @port = @server.add_http2_port "localhost:0", :this_port_is_insecure
      @mock = SpannerMockServer.new
      @server.handle @mock
      # Run the server in a separate thread
      @server_thread = Thread.new do
        @server.run
      end
      @server.wait_till_running
      # Register INFORMATION_SCHEMA queries on the mock server.
      MockServerTests::register_select_tables_result @mock
      MockServerTests::register_singers_columns_result @mock
      MockServerTests::register_singers_indexed_columns_result @mock
      MockServerTests::register_singers_indexes_result @mock
      MockServerTests::register_singers_primary_key_columns_result @mock
      MockServerTests::register_singers_primary_and_parent_key_columns_result @mock
      MockServerTests::register_versioned_singers_columns_result @mock
      MockServerTests::register_versioned_singers_primary_key_columns_result @mock
      MockServerTests::register_versioned_singers_primary_and_parent_key_columns_result @mock
      MockServerTests::register_albums_columns_result @mock
      MockServerTests::register_albums_primary_key_columns_result @mock
      MockServerTests::register_albums_primary_and_parent_key_columns_result @mock
      MockServerTests::register_all_types_columns_result @mock
      MockServerTests::register_all_types_primary_key_columns_result @mock
      MockServerTests::register_all_types_primary_and_parent_key_columns_result @mock
      MockServerTests::register_table_with_commit_timestamps_columns_result @mock
      MockServerTests::register_table_with_commit_timestamps_primary_key_columns_result @mock
      MockServerTests::register_table_with_commit_timestamps_primary_and_parent_key_columns_result @mock
      MockServerTests::register_table_with_sequence_columns_result @mock
      MockServerTests::register_table_with_sequence_primary_key_columns_result @mock
      MockServerTests::register_table_with_sequence_primary_and_parent_key_columns_result @mock
      # Connect ActiveRecord to the mock server
      ActiveRecord::Base.establish_connection(
        adapter: "spanner",
        emulator_host: "localhost:#{@port}",
        project: "test-project",
        instance: "test-instance",
        database: "testdb",
      )
      ActiveRecord::Base.logger = nil
    end

    def teardown
      ActiveRecord::Base.connection_pool.disconnect!
      @server.stop
      @server_thread.exit
      super
    end

    def abort_current_transaction
      connection = ActiveRecord::Base.connection.instance_variable_get(:@connection)
      current_transaction = connection.instance_variable_get(:@current_transaction)
      transaction = current_transaction.instance_variable_get(:@grpc_transaction).instance_variable_get(:@grpc)
      session = connection.session.instance_variable_get(:@grpc)
      @mock.abort_transaction session["name"], transaction["id"]
      true
    end

  end
end
