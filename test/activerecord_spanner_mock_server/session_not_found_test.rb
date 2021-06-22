# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class SessionNotFoundTest < BaseSpannerMockServerTest

    def create_connection_with_invalidated_session
      # Create a connection and a session, and then delete the session.
      ActiveRecord::Base.transaction do
      end
      @mock.delete_all_sessions
      @mock.requests.clear
    end

    def test_session_not_found_single_read
      create_connection_with_invalidated_session
      select_sql = register_singer_find_by_id_result

      Singer.find_by id: 1

      # The request should be executed twice on two different sessions, both times without a transaction selector.
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }
      assert_equal 2, sql_requests.length
      refute_equal sql_requests[0].session, sql_requests[1].session
      refute sql_requests[0].transaction
      refute sql_requests[1].transaction
    end

    def test_session_not_found_implicit_transaction_single_insert
      create_connection_with_invalidated_session
      Singer.create(first_name: "Dave", last_name: "Allison")

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_requests.length
      refute_equal begin_requests[0].session, begin_requests[1].session
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal begin_requests[1].session, commit_requests[0].session
    end

    def test_session_not_found_implicit_transaction_batch_insert
      create_connection_with_invalidated_session
      Singer.create([{first_name: "Dave", last_name: "Allison"}, {first_name: "Alice", last_name: "Becker"}])

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_requests.length
      refute_equal begin_requests[0].session, begin_requests[1].session
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal begin_requests[1].session, commit_requests[0].session
    end

    def test_session_not_found_on_begin_transaction
      create_connection_with_invalidated_session
      Singer.create(first_name: "Dave", last_name: "Allison")

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_requests.length
      refute_equal begin_requests[0].session, begin_requests[1].session
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal begin_requests[1].session, commit_requests[0].session
    end

    def test_session_not_found_on_dml_in_transaction
      insert_sql = register_insert_singer_result

      deleted = nil
      Singer.transaction do
        deleted = @mock.delete_all_sessions unless deleted
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_requests.length
      refute_equal begin_requests[0].session, begin_requests[1].session
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 2, sql_requests.length
      refute_equal sql_requests[0].session, sql_requests[1].session
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal begin_requests[1].session, commit_requests[0].session
    end

    def test_session_not_found_on_select_in_transaction
      select_sql = register_singer_find_by_id_result

      deleted = nil
      Singer.transaction do
        deleted = @mock.delete_all_sessions unless deleted
        Singer.find_by id: 1
      end

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_requests.length
      refute_equal begin_requests[0].session, begin_requests[1].session
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }
      assert_equal 2, sql_requests.length
      refute_equal sql_requests[0].session, sql_requests[1].session
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal begin_requests[1].session, commit_requests[0].session
    end

    def test_session_not_found_on_commit
      insert_sql = register_insert_singer_result

      deleted = nil
      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison")
        deleted = @mock.delete_all_sessions unless deleted
      end

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_requests.length
      refute_equal begin_requests[0].session, begin_requests[1].session
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 2, sql_requests.length
      refute_equal sql_requests[0].session, sql_requests[1].session
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 2, commit_requests.length
      assert_equal begin_requests[1].session, commit_requests[1].session
    end

    def register_insert_singer_result
      sql = "INSERT INTO `singers` (`first_name`, `last_name`, `id`) VALUES (@first_name_1, @last_name_2, @id_3)"
      @mock.put_statement_result sql, StatementResult.new(1)
      sql
    end

    def register_singer_find_by_id_result
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      sql
    end
  end
end
