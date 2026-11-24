# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class TransactionTest < TestHelper::MockActiveRecordTest
  attr_reader :transaction

  def setup
    super
    @transaction = ActiveRecordSpannerAdapter::Transaction.new connection, nil
  end

  def test_begin
    assert_equal :INITIALIZED, transaction.state
    transaction.begin
    assert_equal :STARTED, transaction.state
  end

  def test_commit
    transaction.begin
    transaction.commit
    assert_equal :COMMITTED, transaction.state
  end

  def test_rollback
    transaction.begin
    transaction.rollback
    assert_equal :ROLLED_BACK, transaction.state
  end

  def test_commit_options
    transaction.begin
    transaction.set_commit_options return_commit_stats: true, max_commit_delay: 1000
    transaction.commit
    assert_equal :COMMITTED, transaction.state
    commit_options = transaction.commit_options
    assert commit_options[:return_commit_stats]
    assert_equal 1000, commit_options[:max_commit_delay]
  end

  def test_exclude_txn_from_change_streams
    transaction.exclude_txn_from_change_streams = true
    assert transaction.exclude_txn_from_change_streams
    transaction.begin
    assert_equal true, transaction.begin_transaction_selector.begin.exclude_txn_from_change_streams
    transaction.commit
    assert_equal :COMMITTED, transaction.state
  end

  def test_no_nested_transactions
    transaction.begin

    err = assert_raises(StandardError) {
      transaction.begin
    }
    assert err.message.include?("Nested transactions are not allowed")
  end

  def test_cannot_commit_without_active_transaction
    err = assert_raises(StandardError) {
      transaction.commit
    }
    assert err.message.include?("This transaction is not active")
  end

  def test_cannot_rollback_without_active_transaction
    err = assert_raises(StandardError) {
      transaction.rollback
    }
    assert err.message.include?("This transaction is not active")
  end

  def test_force_begin_read_write_preserves_isolation_level_and_exclude_from_change_streams
    isolation_cases = {
      nil => nil,
      :serializable => Google::Cloud::Spanner::V1::TransactionOptions::IsolationLevel::SERIALIZABLE,
      :repeatable_read => Google::Cloud::Spanner::V1::TransactionOptions::IsolationLevel::REPEATABLE_READ,
      :buffered_mutations => nil,
      :fallback_to_pdml => nil
    }
    exclude_cases = {
      false => false,
      nil => false,
      true => true
    }

    isolation_cases.each do |isolation, expected_grpc|
      exclude_cases.each do |exclude_input, expected_exclude|
        current_transaction = ActiveRecordSpannerAdapter::Transaction.new(
          connection,
          isolation,
          exclude_txn_from_change_streams: exclude_input
        )
        current_transaction.begin
        grpc_transaction = current_transaction.force_begin_read_write

        refute_nil grpc_transaction
        begin_options = connection.session.service.last_begin_transaction_options
        assert_equal expected_exclude, begin_options[:exclude_txn_from_change_streams]
        if expected_grpc.nil?
          assert_nil begin_options[:isolation_level]
        else
          assert_equal expected_grpc, begin_options[:isolation_level]
        end
      end
    end
  end

  def test_force_begin_read_write_respects_post_init_exclude_txn_from_change_streams
    current_transaction = ActiveRecordSpannerAdapter::Transaction.new connection, :repeatable_read
    current_transaction.exclude_txn_from_change_streams = true
    current_transaction.begin
    current_transaction.force_begin_read_write

    begin_options = connection.session.service.last_begin_transaction_options
    assert_equal true, begin_options[:exclude_txn_from_change_streams]
    assert_equal Google::Cloud::Spanner::V1::TransactionOptions::IsolationLevel::REPEATABLE_READ,
                 begin_options[:isolation_level]
  end

  def test_force_begin_read_write_leaves_grpc_transaction_nil_on_error
    current_transaction = ActiveRecordSpannerAdapter::Transaction.new(
      connection,
      :repeatable_read,
      exclude_txn_from_change_streams: true
    )
    current_transaction.begin

    stub_failing_begin_transaction do
      err = assert_raises(Google::Cloud::PermissionDeniedError) do
        current_transaction.force_begin_read_write
      end
      assert_equal "Not permitted", err.message
    end

    assert_nil current_transaction.grpc_transaction?
  end

  def test_mutation_only_commit_preserves_isolation_level_and_exclude_from_change_streams
    current_transaction = ActiveRecordSpannerAdapter::Transaction.new(
      connection,
      :repeatable_read,
      exclude_txn_from_change_streams: true
    )
    current_transaction.begin
    current_transaction.buffer Google::Cloud::Spanner::V1::Mutation.new
    current_transaction.commit

    assert_equal :COMMITTED, current_transaction.state
    begin_options = connection.session.service.last_begin_transaction_options
    assert_equal true, begin_options[:exclude_txn_from_change_streams]
    assert_equal Google::Cloud::Spanner::V1::TransactionOptions::IsolationLevel::REPEATABLE_READ,
                 begin_options[:isolation_level]
  end

  def test_mutation_only_commit_failure_marks_transaction_failed
    current_transaction = ActiveRecordSpannerAdapter::Transaction.new(
      connection,
      :repeatable_read,
      exclude_txn_from_change_streams: true
    )
    current_transaction.begin
    current_transaction.buffer Google::Cloud::Spanner::V1::Mutation.new

    stub_failing_begin_transaction do
      err = assert_raises(Google::Cloud::PermissionDeniedError) do
        current_transaction.commit
      end
      assert_equal "Not permitted", err.message
    end

    assert_equal :FAILED, current_transaction.state
    assert_nil current_transaction.grpc_transaction?
  end

  private

  def stub_failing_begin_transaction(&block)
    failing_begin = lambda do |_session_name, **_options|
      raise Google::Cloud::PermissionDeniedError, "Not permitted"
    end
    connection.session.service.stub :begin_transaction, failing_begin, &block
  end
end
