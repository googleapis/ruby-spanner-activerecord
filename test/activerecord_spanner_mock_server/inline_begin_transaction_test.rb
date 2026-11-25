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
      # Start a transaction, passing the commit_options.
      ActiveRecord::Base.transaction commit_options: options_to_test do
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

    def test_error_on_first_statement_preserves_isolation_level_and_exclude_from_change_streams
      insert_sql = register_insert_singer_result

      [:serializable, :repeatable_read, nil].each do |isolation|
        [true, false, nil].each do |exclude_from_streams|
          @mock.push_error \
            insert_sql,
            GRPC::BadStatus.new(
              GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
              "Too many requests"
            )

          transaction_options = build_transaction_options isolation, exclude_from_streams
          ActiveRecord::Base.transaction(**transaction_options) do
            Singer.create(first_name: "Dave", last_name: "Allison")
          end

          assert_begin_transaction_requests(
            expected_isolation: _transaction_isolation_level_to_grpc(isolation),
            expected_exclude: exclude_from_streams || false
          )

          @mock.requests.clear
        end
      end
    end

    def test_error_on_first_statement_uses_default_connection_isolation_level
      insert_sql = register_insert_singer_result
      ActiveRecord::Base.connection.isolation_level = :repeatable_read
      @mock.push_error \
        insert_sql,
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Too many requests")

      ActiveRecord::Base.transaction exclude_txn_from_change_streams: true do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true
    end

    def test_error_on_first_statement_and_on_begin_transaction_preserves_options
      insert_sql = register_insert_singer_result
      @mock.push_error \
        insert_sql,
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::FAILED_PRECONDITION, "Duplicate key")
      @mock.push_error \
        "begin_transaction",
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, "Not permitted")

      err = assert_raises ActiveRecord::StatementInvalid do
        ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end
      end
      assert err.cause.is_a?(Google::Cloud::FailedPreconditionError)

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true
    end

    def test_error_on_first_batch_dml_preserves_isolation_level_and_exclude_from_change_streams
      sql = "INSERT OR IGNORE INTO `singers` (`first_name`,`last_name`) VALUES ('Alice', 'Ecila')"
      error = GRPC::BadStatus.new GRPC::Core::StatusCodes::INVALID_ARGUMENT, "Invalid value"
      @mock.put_statement_result sql, StatementResult.new(error)

      singer1 = { first_name: "Alice", last_name: "Ecila" }
      singer2 = { first_name: "Pete", last_name: "Etep" }

      [:serializable, :repeatable_read, nil].each do |isolation|
        [true, false, nil].each do |exclude_from_streams|
          transaction_options = build_transaction_options isolation, exclude_from_streams

          ActiveRecord::Base.transaction(**transaction_options) do
            assert_raises Google::Cloud::Spanner::BatchUpdateError do
              ActiveRecord::Base.dml_batch do
                Singer.insert(singer1)
                Singer.insert(singer2)
              end
            end
          end

          assert_begin_transaction_requests(
            expected_isolation: _transaction_isolation_level_to_grpc(isolation),
            expected_exclude: exclude_from_streams || false
          )

          @mock.requests.clear
        end
      end
    end

    def test_error_on_first_batch_dml_uses_default_connection_isolation_level_and_handles_begin_failure
      sql = "INSERT OR IGNORE INTO `singers` (`first_name`,`last_name`) VALUES ('Alice', 'Ecila')"
      error = GRPC::BadStatus.new GRPC::Core::StatusCodes::INVALID_ARGUMENT, "Invalid value"
      @mock.put_statement_result sql, StatementResult.new(error)
      @mock.push_error \
        "begin_transaction",
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::PERMISSION_DENIED, "Not permitted")

      ActiveRecord::Base.connection.isolation_level = :repeatable_read
      singer1 = { first_name: "Alice", last_name: "Ecila" }
      singer2 = { first_name: "Pete", last_name: "Etep" }

      ActiveRecord::Base.transaction exclude_txn_from_change_streams: true do
        assert_raises Google::Cloud::Spanner::BatchUpdateError do
          ActiveRecord::Base.dml_batch do
            Singer.insert(singer1)
            Singer.insert(singer2)
          end
        end
      end

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true
    end

    def test_mutation_only_commit_preserves_isolation_level_and_exclude_from_change_streams
      [:serializable, :repeatable_read, nil].each do |isolation|
        [true, false, nil].each do |exclude_from_streams|
          transaction_options = build_transaction_options isolation, exclude_from_streams

          ActiveRecord::Base.transaction(**transaction_options) do
            ActiveRecord::Base.connection.current_spanner_transaction.buffer build_singer_insert_mutation
          end

          assert_begin_transaction_requests(
            expected_isolation: _transaction_isolation_level_to_grpc(isolation),
            expected_exclude: exclude_from_streams || false
          )
          assert_equal 1, @mock.requests.count { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }

          @mock.requests.clear
        end
      end
    end

    def test_mutation_only_commit_uses_default_connection_isolation_level
      ActiveRecord::Base.connection.isolation_level = :repeatable_read

      ActiveRecord::Base.transaction exclude_txn_from_change_streams: true do
        ActiveRecord::Base.connection.current_spanner_transaction.buffer build_singer_insert_mutation
      end

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true
    end

    def test_mutation_only_commit_session_not_found_retries_with_options
      deleted = false
      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.connection.current_spanner_transaction.buffer build_singer_insert_mutation
        unless deleted
          @mock.delete_all_sessions
          deleted = true
        end
      end

      begin_transaction_requests = assert_begin_transaction_requests(
        expected_isolation: :REPEATABLE_READ,
        expected_exclude: true,
        count: 2
      )
      refute_equal begin_transaction_requests[0].session, begin_transaction_requests[1].session

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal begin_transaction_requests[1].session, commit_requests.first.session
    end

    def test_mutation_only_commit_aborted_retries_with_options
      aborted = false
      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.connection.current_spanner_transaction.buffer build_singer_insert_mutation
        unless aborted
          @mock.abort_next_transaction
          aborted = true
        end
      end

      assert_begin_transaction_requests(
        expected_isolation: :REPEATABLE_READ,
        expected_exclude: true,
        count: 2
      )
      assert_equal 2, @mock.requests.count { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
    end

    def test_error_on_first_statement_then_aborted_commit_retries_with_options
      insert_sql = register_insert_singer_result
      @mock.push_error \
        insert_sql,
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Too many requests")

      aborted = false
      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        Singer.create(first_name: "Dave", last_name: "Allison")
        unless aborted
          abort_current_transaction
          aborted = true
        end
      end

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true

      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }
      assert_equal 3, sql_requests.length
      assert sql_requests[0].transaction&.begin&.read_write
      assert sql_requests[1].transaction&.id
      assert sql_requests[2].transaction&.begin&.read_write
      assert_equal :REPEATABLE_READ, sql_requests[2].transaction&.begin&.isolation_level
      assert_equal true, sql_requests[2].transaction&.begin&.exclude_txn_from_change_streams
    end

    def test_mixed_mutation_and_failed_first_statement_preserves_options
      insert_sql = register_insert_singer_result
      @mock.push_error \
        insert_sql,
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Too many requests")

      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.connection.current_spanner_transaction.buffer build_singer_insert_mutation
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true

      commit_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal 1, commit_requests.first.mutations.length
    end

    def test_mixed_mutation_and_successful_sql_uses_inline_begin
      insert_sql = register_insert_singer_result

      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.connection.current_spanner_transaction.buffer build_singer_insert_mutation
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      begin_transaction_requests = @mock.requests.select { |request| request.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests

      assert_inline_begin_sql_requests insert_sql, expected_isolation: :REPEATABLE_READ, expected_exclude: true

      commit_requests = @mock.requests.select { |request| request.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_equal 1, commit_requests.length
      assert_equal 1, commit_requests.first.mutations.length
    end

    def test_nested_joinable_transaction_preserves_outer_options_on_force_begin
      insert_sql = register_insert_singer_result
      @mock.push_error \
        insert_sql,
        GRPC::BadStatus.new(GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED, "Too many requests")

      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.transaction do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end
      end

      assert_begin_transaction_requests expected_isolation: :REPEATABLE_READ, expected_exclude: true
    end

    def test_nested_joinable_transaction_preserves_outer_options_on_retry
      insert_sql = register_insert_singer_result
      aborted = false
      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.transaction do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end
        unless aborted
          abort_current_transaction
          aborted = true
        end
      end

      assert_inline_begin_sql_requests(
        insert_sql,
        expected_isolation: :REPEATABLE_READ,
        expected_exclude: true,
        count: 2
      )
    end

    def test_nested_requires_new_transaction_preserves_outer_options_on_retry
      insert_sql = register_insert_singer_result
      aborted = false
      ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
        ActiveRecord::Base.transaction requires_new: true do
          Singer.create(first_name: "Dave", last_name: "Allison")
        end
        unless aborted
          abort_current_transaction
          aborted = true
        end
      end

      assert_inline_begin_sql_requests(
        insert_sql,
        expected_isolation: :REPEATABLE_READ,
        expected_exclude: true,
        count: 2
      )
    end

    def test_exception_in_transaction_does_not_leak_transaction_options
      assert_raises(RuntimeError) do
        ActiveRecord::Base.transaction isolation: :repeatable_read, exclude_txn_from_change_streams: true do
          raise "boom"
        end
      end

      insert_sql = register_insert_singer_result
      ActiveRecord::Base.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      assert_inline_begin_sql_requests(
        insert_sql,
        expected_isolation: :ISOLATION_LEVEL_UNSPECIFIED,
        expected_exclude: false
      )
    end

    def test_fallback_to_pdml_does_not_leak_transaction_options
      update_sql = "UPDATE `singers` SET `last_name` = @p1 WHERE TRUE"
      @mock.push_error \
        update_sql,
        GRPC::BadStatus.new(
          GRPC::Core::StatusCodes::INVALID_ARGUMENT,
          "Transaction mutation limit exceeded"
        )
      @mock.put_statement_result update_sql, StatementResult.new(10)

      TableWithSequence.transaction isolation: :fallback_to_pdml, exclude_txn_from_change_streams: true do
        Singer.update_all last_name: "Updated"
      end

      insert_sql = register_insert_singer_result
      ActiveRecord::Base.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      assert_inline_begin_sql_requests(
        insert_sql,
        expected_isolation: :ISOLATION_LEVEL_UNSPECIFIED,
        expected_exclude: false
      )
    end

    def test_buffered_mutations_preserves_exclude_from_change_streams
      [true, false, nil].each do |exclude_from_streams|
        transaction_options = build_transaction_options :buffered_mutations, exclude_from_streams

        User.transaction(**transaction_options) do
          User.create!(email: "test@example.com", full_name: "Test User")
        end

        assert_begin_transaction_requests(
          expected_isolation: :ISOLATION_LEVEL_UNSPECIFIED,
          expected_exclude: exclude_from_streams || false
        )

        @mock.requests.clear
      end
    end

    def test_buffered_mutations_aborted_retry_preserves_exclude_from_change_streams
      aborted = false
      User.transaction isolation: :buffered_mutations, exclude_txn_from_change_streams: true do
        unless aborted
          @mock.abort_next_transaction
          aborted = true
        end
        User.create!(email: "test@example.com", full_name: "Test User")
      end

      assert_begin_transaction_requests(
        expected_isolation: :ISOLATION_LEVEL_UNSPECIFIED,
        expected_exclude: true,
        count: 2
      )
    end

    def build_transaction_options isolation, exclude_from_streams
      transaction_options = { isolation: isolation }
      transaction_options[:exclude_txn_from_change_streams] = exclude_from_streams unless exclude_from_streams.nil?
      transaction_options
    end

    def assert_inline_begin_sql_requests sql, expected_isolation:, expected_exclude:, count: 1
      sql_requests = @mock.requests.select do |request|
        request.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && request.sql == sql
      end
      assert_equal count, sql_requests.length
      sql_requests.each do |request|
        begin_options = request.transaction&.begin
        assert begin_options&.read_write
        assert_equal expected_isolation, begin_options&.isolation_level
        assert_equal expected_exclude, begin_options&.exclude_txn_from_change_streams
      end
      sql_requests
    end

    def assert_begin_transaction_requests expected_isolation:, expected_exclude:, count: 1
      begin_transaction_requests = @mock.requests.select { |request| request.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal count, begin_transaction_requests.length
      begin_transaction_requests.each do |request|
        begin_options = request.options
        assert begin_options&.read_write
        assert_equal expected_isolation, begin_options&.isolation_level
        assert_equal expected_exclude, begin_options&.exclude_txn_from_change_streams
      end
      begin_transaction_requests
    end

    def build_singer_insert_mutation
      Google::Cloud::Spanner::V1::Mutation.new(
        insert: Google::Cloud::Spanner::V1::Mutation::Write.new(
          table: "singers",
          columns: ["id", "first_name", "last_name"],
          values: [
            Google::Protobuf::ListValue.new(
              values: [
                Google::Protobuf::Value.new(string_value: "1"),
                Google::Protobuf::Value.new(string_value: "Dave"),
                Google::Protobuf::Value.new(string_value: "Allison")
              ]
            )
          ]
        )
      )
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
