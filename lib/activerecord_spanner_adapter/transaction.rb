# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecordSpannerAdapter
  class Transaction
    attr_reader :state

    def initialize connection
      @connection = connection
      @state = :INITIALIZED
      @sequence_number = 0
    end

    def active?
      @state == :STARTED
    end

    def begin
      raise "Nested transactions are not allowed" if @state != :INITIALIZED
      begin
        @grpc_transaction = @connection.session.create_transaction
        @state = :STARTED
      rescue StandardError
        @state = :FAILED
        raise
      end
    end

    def next_sequence_number
      @sequence_number += 1
    end

    def commit
      raise "This transaction is not active" unless active?

      begin
        @connection.session.commit_transaction @grpc_transaction
        @state = :COMMITTED
      rescue StandardError
        @state = :FAILED
        raise
      end
    end

    def rollback
      # Allow rollback after abort and/or a failed commit.
      raise "This transaction is not active" unless active? || @state == :FAILED || @state == :ABORTED
      if active?
        @connection.session.rollback @grpc_transaction.transaction_id
      end
      @state = :ROLLED_BACK
    end

    def mark_aborted
      @state = :ABORTED
    end

    def transaction_selector
      return unless active?

      Google::Spanner::V1::TransactionSelector.new \
        id: @grpc_transaction.transaction_id
    end
  end
end
