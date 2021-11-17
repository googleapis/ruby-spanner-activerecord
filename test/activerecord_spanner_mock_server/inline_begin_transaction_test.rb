# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class InlineTransactionTest < BaseSpannerMockServerTest
    def test_read_write_transaction_uses_inlined_begin
      insert_sql = register_insert_singer_result

      ActiveRecord::Base.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      # There should be no explicit BeginTransaction request.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert sql_request.transaction&.begin&.read_write

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
    end

    def test_read_write_transaction_aborted_dml_is_automatically_retried_with_inline_begin
      insert_sql = register_insert_singer_result

      already_aborted = false
      ActiveRecord::Base.transaction do
        already_aborted = @mock.abort_next_transaction unless already_aborted
        # The following statement will fail with an Aborted error. That will cause the entire
        # transaction block to be retried.
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      # There should be two transaction attempts, two ExecuteSqlRequests and only one commit.
      # Both transaction attempts should use an inlined BeginTransaction.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 2, sql_requests.length
      sql_requests.each { |req| assert req.transaction&.begin&.read_write }

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
      assert_empty rollback_requests
    end

    def test_read_write_transaction_aborted_query_is_automatically_retried_with_inline_begin
      select_sql = register_singer_find_by_id_result

      already_aborted = false
      ActiveRecord::Base.transaction do
        already_aborted = @mock.abort_next_transaction unless already_aborted
        Singer.find_by id: 1
      end

      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }
      assert_equal 2, sql_requests.length
      sql_requests.each { |req| assert req.transaction&.begin&.read_write }
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
      assert_empty rollback_requests
    end

    def test_read_write_transaction_aborted_commit_is_automatically_retried_with_inline_begin
      select_sql = register_singer_find_by_id_result

      already_aborted = false
      ActiveRecord::Base.transaction do
        Singer.find_by id: 1
        already_aborted = abort_current_transaction unless already_aborted
      end

      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }
      assert_equal 2, sql_requests.length
      sql_requests.each { |req| assert req.transaction&.begin&.read_write }
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 2, commit_requests.length
      rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
      assert_empty rollback_requests
    end

    def test_implicit_transaction_aborted_single_insert_is_automatically_retried_without_inline_begin
      # This will abort the next transaction that is started on the mock server.
      @mock.abort_next_transaction
      # The following statement will automatically start a transaction, although it is not in a transaction block.
      # The transaction is automatically retried if the transaction is aborted.
      # It will not inline the BeginTransaction option, as it only uses mutations.
      Singer.create(first_name: "Dave", last_name: "Allison")

      # There should be two transaction attempts.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_transaction_requests.length
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 2, commit_requests.length
      rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
      assert_empty rollback_requests
    end

    def test_implicit_transaction_aborted_batch_insert_is_automatically_retried_without_inline_begin
      @mock.abort_next_transaction
      Singer.create([{first_name: "Dave", last_name: "Allison"}, {first_name: "Alice", last_name: "Becker"}])

      # The batch will be inserted as one transaction containing two mutations. The first attempt will abort, and
      # the second will succeed.
      # It will not inline the BeginTransaction option, as it only uses mutations.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 2, begin_transaction_requests.length
      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 2, commit_requests.length
      rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
      assert_empty rollback_requests
    end

    def register_insert_singer_result
      sql = "INSERT INTO `singers` (`first_name`, `last_name`, `id`) VALUES (@p1, @p2, @p3)"
      @mock.put_statement_result sql, StatementResult.new(1)
      sql
    end

    def register_singer_find_by_id_result
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      sql
    end
  end
end
