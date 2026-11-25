# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class WriterSinger < ActiveRecord::Base
    self.table_name = "singers"
  end

  class ReaderSinger < ActiveRecord::Base
    self.table_name = "singers"
  end

  class ConnectionCacheMockServerTest < BaseSpannerMockServerTest
    def teardown
      WriterSinger.remove_connection if WriterSinger.connected?
      ReaderSinger.remove_connection if ReaderSinger.connected?
    ensure
      super
      ActiveRecordSpannerAdapter::Connection.reset_spanners!
    end

    def test_separate_roles_for_same_database_do_not_share_spanner_client_or_information_schema
      shared_config = {
        adapter: "spanner",
        emulator_host: "localhost:#{@port}",
        project: "test-project",
        instance: "test-instance",
        database: "testdb"
      }

      WriterSinger.establish_connection shared_config.merge(credentials: "writer-key.json")
      ReaderSinger.establish_connection shared_config.merge(credentials: "reader-key.json")

      writer_adapter = WriterSinger.connection
      reader_adapter = ReaderSinger.connection

      writer_connection = writer_adapter.instance_variable_get :@connection
      reader_connection = reader_adapter.instance_variable_get :@connection

      refute_same writer_connection.spanner, reader_connection.spanner

      writer_info_schema = writer_adapter.send :information_schema
      reader_info_schema = reader_adapter.send :information_schema

      refute_same writer_info_schema, reader_info_schema
      refute_same writer_info_schema.connection, reader_info_schema.connection
      refute_same writer_info_schema.connection.spanner, reader_info_schema.connection.spanner

      assert_equal WriterSinger.columns.map(&:name), ReaderSinger.columns.map(&:name)

      create_session_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CreateSessionRequest }
      # 1 WriterSinger + 1 ReaderSinger + 2 InformationSchema connections = 4 sessions.
      assert_equal 4, create_session_requests.length
      refute_equal writer_connection.session.path, reader_connection.session.path

      info_schema_sessions = [
        writer_info_schema.connection.session.path,
        reader_info_schema.connection.session.path
      ]
      refute_equal info_schema_sessions[0], info_schema_sessions[1]

      schema_queries = @mock.requests.select do |req|
        req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql.include?("INFORMATION_SCHEMA")
      end
      assert_includes schema_queries.map(&:session).uniq, info_schema_sessions[0]
      assert_includes schema_queries.map(&:session).uniq, info_schema_sessions[1]
    end
  end
end
