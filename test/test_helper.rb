# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"
require "google/cloud/spanner"
require "active_record"
require "activerecord-spanner-adapter"
require "active_record/connection_adapters/spanner_adapter"

module SqlStatmentAssertions
  def assert_sql_equal exp, *act
    exp_sqls = Array(exp).map do |obj|
      obj.respond_to?(:sql) ? obj.sql : obj
    end.flatten

    act_sqls = Array(act).flatten.map do |obj|
      obj.respond_to?(:sql) ? obj.sql : obj
    end.flatten

    exp_sqls = exp_sqls.map do |v|
      v.to_s.split("\n").map{|v| v.squeeze(" ").strip}.join
    end
    act_sqls = act_sqls.map do |v|
      v.to_s.split("\n").map{|v| v.squeeze(" ").strip}.join
    end

    assert_equal exp_sqls, act_sqls
  end
end

module TestHelper
  class MockActiveRecordTest < Minitest::Test
    include SqlStatmentAssertions

    attr_reader :project_id, :instance_id, :database_id, :credentials,
                :connection

    def setup
      super

      @project_id = "test-project"
      @instance_id = "test-instance"
      @database_id = "test-database"
      @credentials = "test-credentials-file"

      mock_project =  MockGoogleSpanner::MockProject.new
      ActiveRecordSpannerAdapter::Connection.stub :spanners, mock_project do
        @connection = ActiveRecordSpannerAdapter::Connection.new(
          project: project_id,
          instance: instance_id,
          database: database_id,
          credentials: credentials,
        )
      end
    end

    def teardown
      MockGoogleSpanner.clear_mocked_executed_sql_and_results
    end

    def set_mocked_result result = nil, &block
      MockGoogleSpanner.mocked_result = block || result
    end

    def last_executed_sqls
      MockGoogleSpanner.last_executed_sqls
    end

    def last_executed_sql
      MockGoogleSpanner.last_executed_sqls.last
    end

    def new_table table_name: nil, parent_table_name: nil, on_delete: nil,
      schema_name: "", catalog: ""
      ActiveRecordSpannerAdapter::Table.new(
        table_name || "table_#{SecureRandom.hex(4)}",
        parent_table: parent_table_name,
        on_delete: on_delete,
        schema_name: schema_name,
        catalog: catalog
      )
    end

    def new_table_column table_name: nil, column_name: nil, type: "INT64",
      limit: nil, ordinal_position: 0, nullable: true,
      allow_commit_timestamp: nil
      ActiveRecordSpannerAdapter::Table::Column.new(
        table_name || "table_#{SecureRandom.hex(4)}",
        column_name || "column_#{SecureRandom.hex(4)}",
        type, limit: limit,
        ordinal_position: ordinal_position, nullable: nullable,
        allow_commit_timestamp: allow_commit_timestamp
      )
    end

    def new_index_column table_name: nil, index_name: nil, column_name: nil,
      order: "ASC", ordinal_position: 0
      ActiveRecordSpannerAdapter::Index::Column.new(
        table_name || "table-#{SecureRandom.hex(4)}",
        index_name || "index-#{SecureRandom.hex(4)}",
        column_name || "column-#{SecureRandom.hex(4)}",
        order: order,
        ordinal_position: ordinal_position
      )
    end

    def new_index table_name: nil, index_name: nil, columns: [],
                  type: nil, unique: false, null_filtered: false,
                  interleve_in: nil, storing: [], state: "READY"
      ActiveRecordSpannerAdapter::Index.new(
        table_name || "table-#{SecureRandom.hex(4)}",
        index_name || "index-#{SecureRandom.hex(4)}",
        columns, type: nil, unique: unique, null_filtered: null_filtered,
        interleve_in: interleve_in, storing: storing, state: state
      )
    end
  end
end

module MockGoogleSpanner
  def self.mocked_result= result
    @mocked_result ||= []
    @mocked_result << result
  end

  def self.mocked_result
    return unless @mocked_result
    result = @mocked_result.shift
    return result.call if result&.is_a? Proc
    result
  end

  def self.clear_mocked_executed_sql_and_results
    @mocked_result = nil
    @last_executed_sqls = nil
  end

  def self.last_executed_sqls sql = nil
    if sql
      @last_executed_sqls ||= []
      @last_executed_sqls << sql
    end
    @last_executed_sqls
  end

  class MockProject
    def initialize *args
      @connection_args = args
    end

    def project_id
      @connection_args.first
    end

    def create_database instance_id, database_id
      MockJob.execute request: {
        instance_id: instance_id, database_id: database_id
      }
    end

    def service
      MockService.new
    end

    def database *args
      MockDatabase.new(*args)
    end

    def create_session *args
      MockSession.new(*args)
    end
  end

  class MockSession
    attr_reader :connection_args

    def initialize *args
      @connection_args = args
    end

    def path
      "/project_id/1/instance_id/2/database_id/3/session/4"
    end

    def release!
      nil
    end

    def execute_query sql, params: nil, types: nil, transaction: nil,
                      partition_token: nil, request_options: nil, seqno: nil
      MockGoogleSpanner.last_executed_sqls OpenStruct.new(
        sql: sql, options: {
          params: params, types: types, transaction: transaction,
          partition_token: partition_token, request_options: request_options,
          seqno: seqno
        }
      )
      OpenStruct.new(rows: MockGoogleSpanner.mocked_result || [])
    end
    alias execute execute_query

    def create_transaction
      grpc = Google::Cloud::Spanner::V1::Transaction.new id: SecureRandom.base64
      Google::Cloud::Spanner::Transaction.from_grpc grpc, self
    end

    def commit_transaction transaction, mutations
      Time.now
    end

    def rollback transaction_id
      true
    end

    def snapshot options = {}
      yield self
    end

    def last_executed_statements
      @last_query&.sql
    end
  end

  class MockDatabase
    attr_reader :connection_args

    def initialize *args
      @connection_args = args
    end

    def update statements: nil, operation_id: nil
      MockGoogleSpanner.last_executed_sqls \
        OpenStruct.new sql: statements, options: { operation_id: operation_id }
      MockJob.execute statements
    end
  end

  class MockService
    attr_reader :connection_args

    def initialize *args
      @connection_args = args
    end

    def create_snapshot session_name, strong: nil, timestamp: nil,
                        staleness: nil
      Google::Cloud::Spanner::V1::Transaction.new id: SecureRandom.base64
    end

    def update statements: nil, operation_id: nil
      MockGoogleSpanner.last_executed_sqls \
        OpenStruct.new sql: statements, options: { operation_id: operation_id }
      MockJob.execute statements
    end
  end

  class MockJob
    attr_accessor :error, :request, :result

    def initialize error: nil, done: true, request: nil, result: nil
      @error = error
      @done = done
      @result = result
      @request = request
    end

    def wait_until_done!
      true
    end

    def error?
      !@error.nil?
    end

    def done?
      @done
    end

    def method_missing m, *args, &block
      @result
    end

    def self.execute request
      job = new request: request

      begin
        job.result = MockGoogleSpanner.mocked_result
      rescue StandardError => e
        job.error = e
      end

      job
    end
  end
end
