require "google/cloud/spanner"
require "spanner_client_ext"
require "spanner_activerecord/information_schema"

module SpannerActiverecord
  class Connection
    Transaction = Struct.new :id, :seqno

    attr_reader :spanner

    def initialize service, session
      @service = service
      @session = session
    end

    def database_id
      @session.database_id
    end

    def active?
      @session.execute_query "SELECT 1"
      true
    rescue StandardError
      false
    end

    def disconnect!
      @session.release!
    end

    def reset!
      @session.reload!
    end

    # DDL Statement

    # @params [Array<String>, String] sql Single or list of statements
    def execute_ddl statements, operation_id: nil
      @service.execute_ddl statements, operation_id: operation_id
    end

    # DQL, DML Statements

    def execute_query sql, params: nil, types: nil
      if params
        params, types = \
          Gooogle::Cloud::Spanner::Convert.to_input_params_and_types(
            params, types
          )
      end

      @session.execute_query(
        sql, params: params, types: types, transaction: transaction_selector,
        seqno: (current_transaction&.seqno += 1)
      ).rows
    end

    def begin_trasaction
      self.current_transaction = @session.begin_transaction.id
    end

    def commit_trransaction deadline: 120
      return unless current_transaction

      start_time = Time.now
      @session.commit_transaction current_transaction.id
    rescue GRPC::Aborted, Google::Cloud::AbortedError => err
      if Time.now - start_time > deadline
        err = Google::Cloud::Error.from_error err if err.is_a? GRPC::BadStatus
        raise err
      end
      # TODO: Handle retry delay delay_from_aborted error
      begin_transaction
      retry
    ensure
      clear_current_transaction
    end

    def rollback_transaction
      return unless current_transaction

      @session.rollback current_transaction.id
    ensure
      clear_current_transaction
    end

    def transaction_selector
      return unless current_transaction
      Google::Spanner::V1::TransactionSelector.new id: current_transaction.id
    end

    def current_transaction
      Thread.current[:session_txn]
    end

    def current_transaction= id
      Thread.current[:session_txn] = Transaction.new id, 0
    end

    def clear_current_transaction
      Thread.current[:session_txn] = nil
    end
  end
end
