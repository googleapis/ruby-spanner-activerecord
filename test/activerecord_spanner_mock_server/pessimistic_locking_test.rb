# Copyright 2025 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class PessimisticLockingTest < BaseSpannerMockServerTest
    def test_select_for_update
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2 FOR UPDATE"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      ActiveRecord::Base.transaction do
        singer = Singer.lock.find(1)

        refute_nil singer
        refute_nil singer.first_name
        refute_nil singer.last_name
      end

      sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }.first
      assert sql_request.transaction&.begin&.read_write

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
    end

    def test_lock_one_entity
      sql_without_lock = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      sql_with_lock = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2 FOR UPDATE"
      @mock.put_statement_result sql_without_lock, MockServerTests::create_random_singers_result(1)
      @mock.put_statement_result sql_with_lock, MockServerTests::create_random_singers_result(1)
      ActiveRecord::Base.transaction do
        singer = Singer.find(1)
        singer.lock!
      end

      sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql_without_lock }.first
      assert sql_request.transaction&.begin&.read_write

      sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql_with_lock }.first
      assert sql_request.transaction&.id

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
    end
  end
end
