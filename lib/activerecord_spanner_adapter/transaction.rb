# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecordSpannerAdapter
  class Transaction
    attr_reader :state

    def initialize connection, isolation
      @connection = connection
      @isolation = isolation
      @state = :INITIALIZED
      @sequence_number = 0
      @mutations = []
    end

    def active?
      @state == :STARTED
    end

    def isolation
      return nil unless active?
      @isolation
    end

    def buffer mutation
      @mutations << mutation
    end

    def begin
      raise "Nested transactions are not allowed" if @state != :INITIALIZED
      begin
        @grpc_transaction =
          if @isolation == :read_only
            @connection.session.create_snapshot strong: true
          else
            @connection.session.create_transaction
          end
        @state = :STARTED
      rescue Google::Cloud::NotFoundError => e
        if @connection.session_not_found? e
          @connection.reset!
          retry
        end
        @state = :FAILED
        raise
      rescue StandardError
        @state = :FAILED
        raise
      end
    end

    def next_sequence_number
      @sequence_number += 1 unless @isolation == :read_only
    end

    def commit
      raise "This transaction is not active" unless active?

      begin
        @connection.session.commit_transaction @grpc_transaction, @mutations unless @isolation == :read_only
        @state = :COMMITTED
      rescue Google::Cloud::NotFoundError => e
        if @connection.session_not_found? e
          shoot_and_forget_rollback
          @connection.reset!
          @connection.raise_aborted_err
        end
        @state = :FAILED
        raise
      rescue StandardError
        @state = :FAILED
        raise
      end
    end

    def rollback
      # Allow rollback after abort and/or a failed commit.
      raise "This transaction is not active" unless active? || @state == :FAILED || @state == :ABORTED
      if active?
        # We do a shoot-and-forget rollback here, as the error that caused the transaction to be rolled back could
        # also have invalidated the transaction (e.g. `Session not found`). If the rollback fails for any other
        # reason, we also do not need to retry it or propagate the error to the application, as the transaction will
        # automatically be aborted by Cloud Spanner after 10 seconds anyways.
        shoot_and_forget_rollback
      end
      @state = :ROLLED_BACK
    end

    def shoot_and_forget_rollback
      @connection.session.rollback @grpc_transaction.transaction_id unless @isolation == :read_only
    rescue StandardError # rubocop:disable Lint/HandleExceptions
      # Ignored
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
