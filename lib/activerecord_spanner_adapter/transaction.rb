# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecordSpannerAdapter
  class Transaction
    attr_reader :state
    attr_reader :commit_options
    attr_accessor :exclude_txn_from_change_streams



    def initialize connection, isolation, commit_options = nil, exclude_txn_from_change_streams: false
      @connection = connection
      @isolation = isolation
      @committable = ![:read_only, :pdml].include?(isolation) && !isolation.is_a?(Hash)
      @state = :INITIALIZED
      @sequence_number = 0
      @mutations = []
      @commit_options = commit_options
      @exclude_txn_from_change_streams = exclude_txn_from_change_streams
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

    # Begins the transaction.
    #
    # Read-only and PDML transactions are started by executing a BeginTransaction RPC.
    # Read/write transactions are not really started by this method, and instead a
    # transaction selector is prepared that will be included with the first statement
    # on the transaction.
    def begin
      raise "Nested transactions are not allowed" if @state != :INITIALIZED
      begin
        case @isolation
        when Hash
          if @isolation[:timestamp]
            @grpc_transaction = @connection.session.create_snapshot timestamp: @isolation[:timestamp]
          elsif @isolation[:staleness]
            @grpc_transaction = @connection.session.create_snapshot staleness: @isolation[:staleness]
          elsif @isolation[:strong]
            @grpc_transaction = @connection.session.create_snapshot strong: true
          else
            raise "Invalid snapshot argument: #{@isolation}"
          end
        when :read_only
          @grpc_transaction = @connection.session.create_snapshot strong: true
        when :pdml
          @grpc_transaction = @connection.session.create_pdml
        else
          grpc_isolation = _transaction_isolation_level_to_grpc @isolation
          @begin_transaction_selector = Google::Cloud::Spanner::V1::TransactionSelector.new \
            begin: Google::Cloud::Spanner::V1::TransactionOptions.new(
              read_write: Google::Cloud::Spanner::V1::TransactionOptions::ReadWrite.new,
              isolation_level: grpc_isolation,
              exclude_txn_from_change_streams: @exclude_txn_from_change_streams
            )
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

    def _transaction_isolation_level_to_grpc isolation
      case isolation
      when :serializable
        Google::Cloud::Spanner::V1::TransactionOptions::IsolationLevel::SERIALIZABLE
      when :repeatable_read
        Google::Cloud::Spanner::V1::TransactionOptions::IsolationLevel::REPEATABLE_READ
      end
    end

    # Forces a BeginTransaction RPC for a read/write transaction. This is used by a
    # connection if the first statement of a transaction failed.
    def force_begin_read_write
      @grpc_transaction = @connection.session.create_transaction
    end

    def next_sequence_number
      @sequence_number += 1 if @committable
    end

    # Sets the commit options for this transaction.
    # This is used to set the options for the commit RPC, such as return_commit_stats and max_commit_delay.
    def set_commit_options options # rubocop:disable Naming/AccessorMethodName
      @commit_options = options&.dup
    end

    def commit
      raise "This transaction is not active" unless active?

      begin
        # Start a transaction with an explicit BeginTransaction RPC if the transaction only contains mutations.
        force_begin_read_write if @committable && !@mutations.empty? && !@grpc_transaction
        if @committable && @grpc_transaction
          @connection.session.commit_transaction @grpc_transaction,
                                                 @mutations,
                                                 commit_options: commit_options,
                                                 exclude_txn_from_change_streams: exclude_txn_from_change_streams
        end
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
      if active? && @grpc_transaction
        # We do a shoot-and-forget rollback here, as the error that caused the transaction to be rolled back could
        # also have invalidated the transaction (e.g. `Session not found`). If the rollback fails for any other
        # reason, we also do not need to retry it or propagate the error to the application, as the transaction will
        # automatically be aborted by Cloud Spanner after 10 seconds anyways.
        shoot_and_forget_rollback
      end
      @state = :ROLLED_BACK
    end

    def shoot_and_forget_rollback
      @connection.session.rollback @grpc_transaction.transaction_id if @committable
    rescue StandardError
      # Ignored
    end

    def mark_aborted
      @state = :ABORTED
    end

    # Sets the underlying gRPC transaction to use for this Transaction.
    # This is used for queries/DML statements that inlined the BeginTransaction option and returned
    # a transaction in the metadata.
    def grpc_transaction= grpc
      @grpc_transaction = Google::Cloud::Spanner::Transaction.from_grpc grpc, @connection.session
    end

    def transaction_selector
      return unless active?

      # Use the transaction that has been started by a BeginTransaction RPC or returned by a
      # statement, if present.
      return Google::Cloud::Spanner::V1::TransactionSelector.new id: @grpc_transaction.transaction_id \
          if @grpc_transaction

      # Return a transaction selector that will instruct the statement to also start a transaction
      # and return its id as a side effect.
      @begin_transaction_selector
    end
  end
end
