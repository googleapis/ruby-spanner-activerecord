# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require_relative "./spanner_mock_server"
require_relative "../test_helper"

require "grpc"
require "gapic/grpc/service_stub"
require "securerandom"

require "google/spanner/v1/spanner_pb"
require "google/spanner/v1/spanner_services_pb"
require "google/cloud/spanner/v1/spanner"

describe "Spanner Mock Server" do

  before do
    @server = GRPC::RpcServer.new
    @port = @server.add_http2_port "localhost:0", :this_port_is_insecure
    @mock = SpannerMockServer.new
    @server.handle @mock
    # Run the server in a separate thread
    @server_thread = Thread.new do
      @server.run
    end
    @server.wait_till_running
    @client = V1::Spanner::Client.new do |config|
      config.credentials = :this_channel_is_insecure
      config.endpoint = "localhost:#{@port}"
    end
  end

  after do
    @server.stop
    @server_thread.exit
  end

  it "creates single session" do
    session = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    _(session.name).must_match "projects/p/instances/i/databases/d/sessions/"
  end

  it "creates batch of sessions" do
    response = @client.batch_create_sessions V1::BatchCreateSessionsRequest.new(
      database: "projects/p/instances/i/databases/d",
      session_count: 2
    )
    _(response.session.length).must_equal 2
    response.session.each do |session|
      _(session.name).must_match "projects/p/instances/i/databases/d/sessions/"
    end
  end

  it "gets session" do
    created = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    session = @client.get_session V1::GetSessionRequest.new name: created.name
    _(session.name).must_match created.name
  end

  it "lists sessions" do
    created = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    paged_response = @client.list_sessions V1::ListSessionsRequest.new database: "projects/p/instances/i/databases/d"
    _((paged_response.response.sessions.select {|session| session.name == created.name}).length).must_equal 1
  end

  it "deletes session" do
    created = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    @client.delete_session V1::DeleteSessionRequest.new name: created.name
    paged_response = @client.list_sessions V1::ListSessionsRequest.new database: "projects/p/instances/i/databases/d"
    _((paged_response.response.sessions.select {|session| session.name == created.name}).length).must_equal 0
  end

  it "can execute SELECT 1" do
    session = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    resultSet = @client.execute_sql V1::ExecuteSqlRequest.new session: session.name, sql: "SELECT 1"
    _(resultSet.rows.length).must_equal 1 # Number of rows
    _(resultSet.rows[0].values.length).must_equal 1 # Number of columns
    _(resultSet.rows[0].values[0].string_value).must_equal "1" # Value
  end

  it "raises an error" do
    sql = "SELECT * FROM NonExistingTable"
    @mock.put_statement_result(
      sql,
      StatementResult.new(
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::NOT_FOUND,
                            "Table NonExistingTable not found")
      )
    )

    session = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    assert_raises Google::Cloud::NotFoundError do
      @client.execute_sql V1::ExecuteSqlRequest.new session: session.name, sql: sql
    end
  end

  it "returns an update count" do
    sql = "UPDATE TestTable SET Value=1 WHERE TRUE"
    @mock.put_statement_result sql, StatementResult.new(100)

    session = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    update_count = @client.execute_sql V1::ExecuteSqlRequest.new session: session.name, sql: sql
    _(update_count.stats.row_count_exact).must_equal 100
  end

  it "returns a streaming result for SELECT 1" do
    session = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    stream = @client.execute_streaming_sql V1::ExecuteSqlRequest.new session: session.name, sql: "SELECT 1"
    stream.each do |partial|
      _(partial.values.length).must_equal 1 # Number values in partial result set
      _(partial.values[0].string_value).must_equal "1" # Value
    end
  end

  it "can create a random result set" do
    result = StatementResult.create_random_result 100
    _(result.result.metadata.row_type.fields.length).must_equal 8
    _(result.result.rows.length).must_equal 100
    result.each do |partial|
      _(partial.values.length).must_equal 8 # Number values in partial result set
    end
  end

  it "returns a random streaming result" do
    sql = "SELECT * FROM RandomTable"
    @mock.put_statement_result sql, StatementResult.create_random_result(100)

    session = @client.create_session V1::CreateSessionRequest.new database: "projects/p/instances/i/databases/d"
    stream = @client.execute_streaming_sql V1::ExecuteSqlRequest.new session: session.name, sql: sql
    row_count = 0
    stream.each do |partial|
      _(partial.values.length).must_equal 8 # Number values in partial result set
      row_count += 1
    end
    _(row_count).must_equal 100
  end
end
