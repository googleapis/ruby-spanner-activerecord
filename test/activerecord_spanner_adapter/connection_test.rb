# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class SpannerConnectionTest < TestHelper::MockActiveRecordTest
  def test_create_connection
    Google::Cloud::Spanner.stub :new, Object.new do
      connection = ActiveRecordSpannerAdapter::Connection.new({
        project: project_id,
        instance: instance_id,
        database: database_id,
        credentials: credentials
      })
    end

    assert_equal connection.instance_id, instance_id
    assert_equal connection.database_id, database_id
    refute_nil connection.spanner
    refute_nil connection.session
  end

  def test_create_database
    set_mocked_result "#{instance_id}/#{database_id}"
    database = connection.create_database
    assert_equal database, "#{instance_id}/#{database_id}"
  end

  def test_raise_an_error_if_issue_in_connection
    set_mocked_result do
      raise "database already exists"
    end

    assert_raises(Google::Cloud::Error) {
      connection.create_database
    }
  end

  def test_get_database
    database = connection.database
    refute_nil database
  end

  def test_connection_is_active
    connection.connect!
    assert_equal connection.active?, true
  end

  def test_connection_not_active_on_error
    set_mocked_result { raise "database not available" }
    assert_equal connection.active?, false
  end

  def test_disconnect_connection
    set_mocked_result true
    assert_equal connection.disconnect!, true
  end

  def test_reset_connecton
    set_mocked_result true
    assert_equal connection.reset!, true
  end

  def test_execute_query
    set_mocked_result ["test-user"]
    result = connection.execute_query "SELECT * FROM users"
    assert_equal result.rows, ["test-user"]
  end

  def test_execute_ddl_statements
    set_mocked_result true
    statement = "CREATE TABLE users ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    result = connection.execute_ddl statement
    assert_equal result, true

    assert_sql_equal last_executed_sql, statement
  end

  def test_raise_error_on_executing_ddl_statement
    set_mocked_result do
      raise "invalid sql statement"
    end

    assert_raises(Google::Cloud::Error) {
      connection.execute_ddl "invalid sql"
    }
  end

  def test_ddl_batch
    statement1 = "CREATE TABLE users ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    statement2 = "CREATE TABLE sessions ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    connection.ddl_batch do
      result1 = connection.execute_ddl statement1
      result2 = connection.execute_ddl statement2
      assert_equal true, result1
      assert_equal true, result2

      # The connection is in batch mode and should therefore only buffer the statement.
      assert_nil last_executed_sqls
    end
    # The statements should now have be sent as one batch.
    assert_sql_equal [statement1, statement2], last_executed_sql
  end

  def test_empty_ddl_batch
    connection.ddl_batch do
    end
    assert_nil last_executed_sqls
  end

  def test_ddl_batch_with_no_block
     err = assert_raises Google::Cloud::FailedPreconditionError do
       connection.ddl_batch
     end
     assert_match /No block given for the DDL batch/, err.message
  end

  def test_run_ddl_batch
    connection.start_batch_ddl
    statement1 = "CREATE TABLE users ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    statement2 = "CREATE TABLE sessions ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    result1 = connection.execute_ddl statement1
    result2 = connection.execute_ddl statement2
    assert_equal true, result1
    assert_equal true, result2

    # The connection is in batch mode and should therefore only buffer the statement.
    assert_nil last_executed_sqls

    # Run the batch. This should send both statements to Spanner.
    connection.run_batch

    # The statements should be sent as one batch.
    assert_sql_equal [statement1, statement2], last_executed_sql

    # It should be possible to start a new batch after running the previous batch.
    connection.start_batch_ddl
    # Running an empty batch is a no-op.
    connection.run_batch
  end

  def test_abort_ddl_batch
    connection.start_batch_ddl
    statement1 = "CREATE TABLE users ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    statement2 = "CREATE TABLE sessions ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    result1 = connection.execute_ddl statement1
    result2 = connection.execute_ddl statement2
    assert_equal true, result1
    assert_equal true, result2

    # The connection is in batch mode and should therefore only buffer the statement.
    assert_nil last_executed_sqls

    # Abort the batch. This should clear the local buffer.
    connection.abort_batch

    # Trying to run a batch now will cause an error as there is not batch on the connection.
    err = assert_raises Google::Cloud::FailedPreconditionError do
      connection.run_batch
    end
    assert_match /There is no batch active on this connection/, err.message
  end

  def test_begin_transaction
    assert_nil connection.current_transaction

    connection.begin_transaction

    refute_nil connection.current_transaction
    assert connection.current_transaction.active?
  end

  def test_commit_transaction
    connection.begin_transaction
    assert connection.current_transaction.active?

    connection.commit_transaction
    refute connection.current_transaction.active?
  end

  def test_rollback_transaction
    connection.begin_transaction
    assert connection.current_transaction.active?

    connection.rollback_transaction
    refute connection.current_transaction.active?
  end

  def test_no_nested_transactions
    connection.begin_transaction

    err = assert_raises(StandardError) {
      connection.begin_transaction
    }
    assert err.message.include?("Nested transactions are not allowed")
  end

  def test_cannot_commit_without_transaction
    err = assert_raises(StandardError) {
      connection.commit_transaction
    }
    assert err.message.include?("This connection does not have a transaction")
  end

  def test_cannot_rollback_without_transaction
    err = assert_raises(StandardError) {
      connection.rollback_transaction
    }
    assert err.message.include?("This connection does not have a transaction")
  end

  def test_cannot_commit_after_commit
    connection.begin_transaction
    connection.commit_transaction

    err = assert_raises(StandardError) {
      connection.commit_transaction
    }
    assert err.message.include?("This transaction is not active")
  end

  def test_cannot_rollback_after_commit
    connection.begin_transaction
    connection.commit_transaction

    err = assert_raises(StandardError) {
      connection.rollback_transaction
    }
    assert err.message.include?("This transaction is not active")
  end

  def test_cannot_commit_after_rollback
    connection.begin_transaction
    connection.rollback_transaction

    err = assert_raises(StandardError) {
      connection.commit_transaction
    }
    assert err.message.include?("This transaction is not active")
  end

  def test_cannot_rollback_after_commit
    connection.begin_transaction
    connection.rollback_transaction

    err = assert_raises(StandardError) {
      connection.rollback_transaction
    }
    assert err.message.include?("This transaction is not active")
  end

  def test_select_outside_transaction_does_not_initiate_implicit_transaction
    assert_nil connection.current_transaction

    connection.execute_query "SELECT 1"

    assert_nil connection.current_transaction
  end

  def test_transaction_is_cleared_after_select_outside_transaction
    connection.begin_transaction
    connection.commit_transaction
    refute_nil connection.current_transaction

    connection.execute_query "SELECT 1"

    assert_nil connection.current_transaction
  end

  def test_update_outside_transaction_initiates_implicit_transaction
    assert_nil connection.current_transaction

    connection.execute_query "UPDATE FOO SET BAR = 1 WHERE TRUE", transaction_required: true

    refute_nil connection.current_transaction
    refute connection.current_transaction.active?
  end

  def test_ddl_outside_transaction_does_not_initiate_transaction
    assert_nil connection.current_transaction

    connection.execute_ddl "CREATE TABLE FOO"

    assert_nil connection.current_transaction
  end

  def test_ddl_clears_transaction
    connection.begin_transaction
    connection.commit_transaction
    refute_nil connection.current_transaction

    connection.execute_ddl "CREATE TABLE FOO"

    assert_nil connection.current_transaction
  end

  def test_ddl_is_not_allowed_during_transaction
    connection.begin_transaction

    err = assert_raises(StandardError) {
      connection.execute_ddl "CREATE TABLE FOO"
    }
    assert err.message.include?("DDL cannot be executed during a transaction")
  end
end
