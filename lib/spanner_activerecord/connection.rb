require "google/cloud/spanner"
require "spanner_client_ext"
require "spanner_activerecord/information_schema"

module SpannerActiverecord
  class Connection
    Transaction = Struct.new :id, :seqno

    attr_reader :instance_id, :database_id, :spanner

    def initialize config
      @instance_id = config[:instance]
      @database_id = config[:database]
      @spanner = self.class.spanners config
    end

    def self.spanners config
      config = config.symbolize_keys
      @spanners ||= {}
      path = "#{config[:project]}/#{config[:instance]}/#{config[:database]}"
      @spanners[path] ||= Google::Cloud.spanner(
        config[:project],
        config[:credentials],
        scope: config[:scope],
        timeout: config[:timeout],
        client_config: config[:client_config]&.symbolize_keys
      )
    end

    def session
      @session ||= spanner.create_session instance_id, database_id
    end
    alias connect! session

    def active?
      session.execute_query "SELECT 1"
      true
    rescue StandardError
      false
    end

    def disconnect!
      session.release!
      @session = nil
    end

    def reset!
      session.reload!
    end

    # DDL Statements

    # @params [Array<String>, String] sql Single or list of statements
    def execute_ddl statements, operation_id: nil, wait_until_done: true
      job = database.update statements: statements, operation_id: operation_id
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.done?
    end

    # Database Operations

    def create_database
      job = spanner.create_database instance_id, database_id
      job.wait_until_done!
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.database
    end

    def database
      @database ||= begin
        database = spanner.database instance_id, database_id
        unless database
          raise ActiveRecord::NoDatabaseError(
            "#{spanner.project}/#{instance_id}/#{database_id}"
          )
        end
        database
      end
    end

    # DQL, DML Statements

    def execute_query sql, params: nil, types: nil
      if params
        params, types = \
          Google::Cloud::Spanner::Convert.to_input_params_and_types(
            params, types
          )
      end

      session.execute_query(
        sql, params: params, types: types, transaction: transaction_selector,
        seqno: (current_transaction&.seqno += 1)
      )
    end

    def begin_trasaction
      self.current_transaction = session.begin_transaction.id
    end

    def commit_transaction deadline: 120
      return unless current_transaction

      start_time = Time.now
      session.commit_transaction current_transaction.id
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

      session.rollback current_transaction.id
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
