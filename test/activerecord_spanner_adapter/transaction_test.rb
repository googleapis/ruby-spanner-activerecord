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
    transaction.begin
    transaction.exclude_txn_from_change_streams = true
    assert transaction.exclude_txn_from_change_streams
    transaction.commit
    assert_equal :COMMITTED, transaction.state
    assert transaction.exclude_txn_from_change_streams
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
end
