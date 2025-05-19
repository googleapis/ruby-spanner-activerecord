# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"

class SpannerMockServerConnectionTest
  describe "Connection with Spanner Mock Server" do

    before do
      @server = GRPC::RpcServer.new
      @port = @server.add_http2_port('localhost:0', :this_port_is_insecure)
      @mock = SpannerMockServer.new
      @server.handle(@mock)
      # Run the server in a separate thread
      @server_thread = Thread.new do
        @server.run
      end
    end

    after do
      @server.stop
      @server_thread.exit
    end

    # @private
    def create_connection
      ActiveRecordSpannerAdapter::Connection.new({
        project: "test-project",
        instance: "test-instance",
        database: "test-database",
        emulator_host: "localhost:#{@port}"
      })
    end

    it "can execute SELECT 1" do
      connection = create_connection
      result = connection.execute_query "SELECT 1"
      row_count = 0
      result.rows.each do |row|
        _(row[:Col1]).must_equal 1
        row_count += 1
      end
      _(row_count).must_equal 1
      connection.disconnect!

      _(@mock.requests.length).must_equal 4
      _(@mock.requests[0]).must_be_kind_of Google::Cloud::Spanner::V1::CreateSessionRequest
      _(@mock.requests[1]).must_be_kind_of Google::Cloud::Spanner::V1::CreateSessionRequest
      _(@mock.requests[2]).must_be_kind_of Google::Cloud::Spanner::V1::ExecuteSqlRequest
      _(@mock.requests[3]).must_be_kind_of Google::Cloud::Spanner::V1::DeleteSessionRequest
    end

    it "can execute random query" do
      sql = "SELECT * FROM RandomTable"
      @mock.put_statement_result(sql, StatementResult.create_random_result(100))

      connection = create_connection
      result = connection.execute_query(sql)
      row_count = 0
      result.rows.each do |row|
        _(row.fields[:ColBool]).must_equal :BOOL
        _(row.fields[:ColInt64]).must_equal :INT64
        _(row.fields[:ColFloat64]).must_equal :FLOAT64
        _(row.fields[:ColNumeric]).must_equal :NUMERIC
        _(row.fields[:ColString]).must_equal :STRING
        _(row.fields[:ColBytes]).must_equal :BYTES
        _(row.fields[:ColDate]).must_equal :DATE
        _(row.fields[:ColTimestamp]).must_equal :TIMESTAMP
        _(row.fields[:ColJson]).must_equal :JSON

        _(row.fields[0]).must_equal :BOOL
        _(row.fields[1]).must_equal :INT64
        _(row.fields[2]).must_equal :FLOAT64
        _(row.fields[3]).must_equal :NUMERIC
        _(row.fields[4]).must_equal :STRING
        _(row.fields[5]).must_equal :BYTES
        _(row.fields[6]).must_equal :DATE
        _(row.fields[7]).must_equal :TIMESTAMP
        _(row.fields[8]).must_equal :JSON
        row_count += 1
      end
      connection.disconnect!

      _(@mock.requests.length).must_equal 4
      _(@mock.requests[0]).must_be_kind_of Google::Cloud::Spanner::V1::CreateSessionRequest
      _(@mock.requests[1]).must_be_kind_of Google::Cloud::Spanner::V1::CreateSessionRequest
      _(@mock.requests[2]).must_be_kind_of Google::Cloud::Spanner::V1::ExecuteSqlRequest
      _(@mock.requests[3]).must_be_kind_of Google::Cloud::Spanner::V1::DeleteSessionRequest
    end

    it "can execute transaction" do
      sql = "UPDATE TestTable SET SomeValue=1 WHERE Id IN (1,2,3)"
      @mock.put_statement_result(sql, StatementResult.new(3))

      connection = create_connection
      connection.begin_transaction
      update_count = connection.execute_query(sql).row_count
      _(update_count).must_equal 3
    end
  end
end
