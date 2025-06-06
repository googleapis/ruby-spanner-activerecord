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

      [:serializable, :repeatable_read, nil].each { |isolation|
        refute ActiveRecord::Base.connection.isolation_level,
               "Connection should not have a default isolation level"
        ActiveRecord::Base.transaction isolation: isolation do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end

        # There should be no explicit BeginTransaction request.
        begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
        assert_empty begin_transaction_requests
        sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
        assert sql_request.transaction&.begin&.read_write
        assert_equal _transaction_isolation_level_to_grpc(isolation),
                     sql_request.transaction&.begin&.isolation_level

        commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
        assert_equal 1, commit_requests.length

        @mock.requests.clear
      }
    end

    def test_read_write_transaction_with_commit_options
      insert_sql = register_insert_singer_result
      options_to_test = { return_commit_stats: true, max_commit_delay: 1000 }
      [:serializable, :repeatable_read, nil].each do |isolation|
        # Start a transaction, passing both the isolation level and the commit_options.
        ActiveRecord::Base.transaction isolation: isolation, commit_options: options_to_test do
          Singer.create(first_name: "Test", last_name: "User")
        end
        # Find the CommitRequest sent to the mock server.
        commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
        assert_equal 1, commit_requests.length
        commit_request = commit_requests.first
        refute_nil commit_request

        # Assert that the commit_options are present and have the correct values.
        assert_equal true, commit_request.return_commit_stats
        refute_nil commit_request.max_commit_delay
        assert_equal 1, commit_request.max_commit_delay.seconds

        sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
        assert sql_request.transaction&.begin&.read_write
        assert_equal _transaction_isolation_level_to_grpc(isolation),
                    sql_request.transaction&.begin&.isolation_level

        @mock.requests.clear
      end
    end

    def test_read_write_transaction_aborted_dml_is_automatically_retried_with_inline_begin
      insert_sql = register_insert_singer_result

      [:serializable, :repeatable_read, nil].each { |isolation|
        already_aborted = false
        ActiveRecord::Base.transaction isolation: isolation do
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
        sql_requests.each { |req| assert_equal _transaction_isolation_level_to_grpc(isolation), req.transaction&.begin&.isolation_level }

        commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
        assert_equal 1, commit_requests.length
        rollback_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::RollbackRequest }
        assert_empty rollback_requests

        @mock.requests.clear
      }
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

    def test_unhandled_error_on_first_statement_retries_transaction_and_fails
      insert_sql = register_insert_singer_result
      # Push the same error twice, so the same error will be returned both during the initial
      # attempt and during the retry.
      @mock.push_error \
        insert_sql, \
        GRPC::BadStatus.new(
          GRPC::Core::StatusCodes::FAILED_PRECONDITION,
          "A row with the given identifier already exists")
      @mock.push_error \
        insert_sql, \
        GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "A row with the given identifier already exists")

      # The entire transaction should be retried if the first statement in a transaction
      # causes an error with a different error code than Aborted, and the retried transaction
      # should use an explicit BeginTransaction RPC. This is necessary in order to include
      # the statement that caused the error in the transaction, as the error could be an
      # indication of the state of the database during the transaction. A unique key constraint
      # violation for example indicates that a record with a specific key value exists.
      err = assert_raises ActiveRecord::StatementInvalid do
        ActiveRecord::Base.transaction do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end
      end
      assert err.cause.is_a?(Google::Cloud::FailedPreconditionError)

      # There should be one explicit BeginTransaction request.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_transaction_requests.length
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 2, sql_requests.length
      assert sql_requests[0].transaction&.begin&.read_write
      assert sql_requests[1].transaction&.id

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_empty commit_requests
    end

    def test_handled_error_on_first_statement_retries_transaction_and_succeeds
      insert_sql = register_insert_singer_result
      # Push the same error twice, so the same error will be returned both during the initial
      # attempt and during the retry.
      @mock.push_error \
        insert_sql, \
        GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "A row with the given identifier already exists")
      @mock.push_error \
        insert_sql, \
        GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        "A row with the given identifier already exists")

      attempts = 0
      ActiveRecord::Base.transaction do
        begin
          Singer.create(first_name: "Dave", last_name: "Allison")
        rescue ActiveRecord::StatementInvalid
          raise if (attempts += 1) > 1
          # Ignore the error and retry the statement.
          retry
        end
      end

      # There should be one explicit BeginTransaction request.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_transaction_requests.length
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      # There should be 3 ExecuteSqlRequests:
      # 1. The initial attempt that includes a BeginTransaction. This statement will fail and be
      #    retried after an explicit BeginTransaction request.
      # 2. The retried attempt after the BeginTransaction RPC. This statement will also fail, as
      #    the error has been added twice.
      # 3. The error handler in the transaction block will retry the statement once more. This time
      #    the statement will succeed, as the error has only been pushed twice.
      assert_equal 3, sql_requests.length
      assert sql_requests[0].transaction&.begin&.read_write
      assert sql_requests[1].transaction&.id
      assert_equal sql_requests[1].transaction&.id, sql_requests[2].transaction&.id

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal sql_requests[1].transaction&.id, commit_requests[0].transaction_id
    end

    def test_transient_error_on_first_statement_retries_transaction_and_succeeds
      insert_sql = register_insert_singer_result
      # Push the same error only once, so the retried statement will succeed.
      @mock.push_error \
        insert_sql, \
        GRPC::BadStatus.new(
        GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
        "Too many requests")

      ActiveRecord::Base.transaction do
        # This statement will fail once, and then be retried internally after an explicit
        # BeginTransaction RPC. The second attempt will succeed as the error was only pushed once.
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      # There should be one explicit BeginTransaction request.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_transaction_requests.length
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 2, sql_requests.length
      assert sql_requests[0].transaction&.begin&.read_write
      assert sql_requests[1].transaction&.id

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal sql_requests[1].transaction&.id, commit_requests[0].transaction_id
    end

    def test_error_on_first_statement_and_on_begin_transaction
      insert_sql = register_insert_singer_result
      @mock.push_error \
        insert_sql, \
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION,
                            "A row with the given identifier already exists")
      @mock.push_error \
        "begin_transaction", \
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, "Not permitted")

      err = assert_raises ActiveRecord::StatementInvalid do
        ActiveRecord::Base.transaction do
          # This statement will fail and cause an internal retry with an explicit BeginTransaction
          # RPC. That RPC invocation will fail, but the original error from the SQL statement
          # will be the error that is returned.
          Singer.create(first_name: "Dave", last_name: "Allison")
        end
      end
      assert err.cause.is_a?(Google::Cloud::FailedPreconditionError)

      # There should be one explicit BeginTransaction request.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_transaction_requests.length
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 1, sql_requests.length
      assert sql_requests[0].transaction&.begin&.read_write

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_empty commit_requests
    end

    def test_read_write_transaction_uses_default_isolation_level_from_config
      insert_sql = register_insert_singer_result

      # Close the existing connection pool and create a new one with a different
      # default isolation level.
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection(
        adapter: "spanner",
        emulator_host: "localhost:#{@port}",
        project: "test-project",
        instance: "test-instance",
        database: "testdb",
        default_sequence_kind: "BIT_REVERSED_POSITIVE",
        isolation_level: :repeatable_read,
        )

      # Verify the default isolation level.
      assert_equal :repeatable_read, ActiveRecord::Base.connection.isolation_level

      ActiveRecord::Base.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert sql_request.transaction&.begin&.read_write
      assert_equal :REPEATABLE_READ,
                   sql_request.transaction&.begin&.isolation_level
    end

    def test_read_write_transaction_uses_default_isolation_level
      insert_sql = register_insert_singer_result

      [:serializable, :repeatable_read, nil].each { |isolation|
        ActiveRecord::Base.connection.isolation_level = isolation

        ActiveRecord::Base.transaction do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end

        # There should be no explicit BeginTransaction request.
        begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
        assert_empty begin_transaction_requests
        sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
        assert sql_request.transaction&.begin&.read_write
        assert_equal _transaction_isolation_level_to_grpc(isolation),
                     sql_request.transaction&.begin&.isolation_level

        commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
        assert_equal 1, commit_requests.length

        @mock.requests.clear
      }
    end

    def test_read_write_transaction_overrides_default_isolation_level
      insert_sql = register_insert_singer_result

      # Set the default isolation level to :repeatable_read
      ActiveRecord::Base.connection.isolation_level = :repeatable_read

      # Start a transaction with isolation level :serializable.
      # This should override the default isolation level.
      ActiveRecord::Base.transaction isolation: :serializable do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      # There should be no explicit BeginTransaction request.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      sql_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert sql_request.transaction&.begin&.read_write
      assert_equal :SERIALIZABLE,
                   sql_request.transaction&.begin&.isolation_level

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
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

    def _transaction_isolation_level_to_grpc isolation
      case isolation
      when :serializable
        :SERIALIZABLE
      when :repeatable_read
        :REPEATABLE_READ
      else
        :ISOLATION_LEVEL_UNSPECIFIED
      end
    end
  end
end
