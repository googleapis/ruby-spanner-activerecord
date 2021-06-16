# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

class ReadOnlyTransactionTest < BaseSpannerMockServerTest
  def test_creates_and_uses_snapshot
    sql = register_singer_find_by_id_result

    ActiveRecord::Base.transaction isolation: :read_only do
      Singer.find_by(id: 1)
      Singer.find_by(id: 2)
    end

    # There should only be one read-only transaction.
    begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
    assert_equal 1, begin_transaction_requests.length
    assert begin_transaction_requests[0].options.read_only
    assert begin_transaction_requests[0].options.read_only.return_read_timestamp

    execute_sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
    id = execute_sql_requests.first.transaction.id
    execute_sql_requests.each do |req|
      assert_equal id, req.transaction.id
      assert_equal 0, req.seqno
    end
    assert_equal 2, execute_sql_requests.length

    # Even though `commit` is called on the ActiveRecord transaction, that commit should not be propagated
    # to the backend, as read-only transactions cannot be committed.
    commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
    assert_empty commit_requests
  end

  def test_rollback_snapshot
    ActiveRecord::Base.transaction isolation: :read_only do
      raise ActiveRecord::Rollback
    end

    # There should only be one read-only transaction.
    begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
    assert_equal 1, begin_transaction_requests.length
    assert begin_transaction_requests[0].options.read_only

    commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
    assert_empty commit_requests
    # The rollback should not be sent to the backend, as read-only transactions cannot be rolled back.
    rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
    assert_empty rollback_requests
  end

  def test_multiple_snapshots
    register_singer_find_by_id_result

    ActiveRecord::Base.transaction isolation: :read_only do
      Singer.find_by id: 1
    end
    ActiveRecord::Base.transaction isolation: :read_only do
      Singer.find_by id: 1
    end
    ActiveRecord::Base.transaction isolation: :read_only do
      raise ActiveRecord::Rollback
    end
    ActiveRecord::Base.transaction isolation: :read_only do
      raise ActiveRecord::Rollback
    end
    ActiveRecord::Base.transaction isolation: :read_only do
      Singer.find_by id: 1
    end

    begin_transaction_requests = @mock.requests.select { |req|
      req.is_a?(Google::Cloud::Spanner::V1::BeginTransactionRequest) && req.options.read_only }
    assert_equal 5, begin_transaction_requests.length
    commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
    assert_empty commit_requests
    rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
    assert_empty rollback_requests
  end

  def register_singer_find_by_id_result
    sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
    @mock.put_statement_result sql, create_random_singers_result(1)
    sql
  end
end
