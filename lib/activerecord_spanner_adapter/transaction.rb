# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecordSpannerAdapter
  class Transaction
    def initialize connection
      @connection = connection
      @state = :INITIALIZED
      @sequence_number = 0
    end

    def active?
      return @state == :STARTED
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

    def commit deadline: 120
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
      return unless @state == :STARTED

      Google::Spanner::V1::TransactionSelector.new \
        id: @grpc_transaction.transaction_id
    end

    ##
    # Retries the entire read/write transaction.
    def retry_transaction err, deadline: 120
      start_time = Time.now
      backoff = 1.0
      if Time.now - start_time > deadline
        if err.is_a? GRPC::BadStatus
          err = Google::Cloud::Error.from_error err
        end
        raise err
      end
      sleep(delay_from_aborted(err) || backoff *= 1.3)
    end
  end
end
