require "google/cloud/spanner"
require "spanner_client_ext"
require "spanner_activerecord/information_schema"

module SpannerActiverecord
  class Connection
    attr_reader :instance_id, :database_id, :spanner
    attr_accessor :current_transaction

    def initialize config
      @instance_id = config[:instance]
      @database_id = config[:database]
      @spanner = self.class.spanners config
    end

    def self.spanners config
      config = config.symbolize_keys
      @spanners ||= {}
      @mutex ||= Mutex.new
      @mutex.synchronize do
        @spanners[database_path(config)] ||= Google::Cloud.spanner(
          config[:project],
          config[:credentials],
          scope: config[:scope],
          timeout: config[:timeout],
          client_config: config[:client_config]&.symbolize_keys,
          lib_name: "spanner-activerecord-adapter",
          lib_version: SpannerActiverecord::VERSION
        )
      end
    end

    def self.information_schema config
      @information_schemas ||= {}
      @information_schemas[database_path(config)] ||= \
        SpannerActiverecord::InformationSchema.new new(config)
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
      true
    ensure
      @session = nil
    end

    def reset!
      disconnect!
      session
      true
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

    def execute_query sql, params: nil, transaction_required: nil
      if params
        converted_params, types = \
          Google::Cloud::Spanner::Convert.to_input_params_and_types(
            params, nil
          )
      end

      if transaction_required && current_transaction.nil?
        transaction = begin_trasaction
      end

      session.execute_query \
        sql,
        params: converted_params,
        types: types,
        transaction: transaction_selector,
        seqno: (current_transaction&.seqno += 1)
    rescue Google::Cloud::NotFoundError
      # Session is idle for too long then it will throw an error not found.
      # In this case reset and retry.
      reset!
      retry
    ensure
      commit_transaction if transaction
    end

    # Transactions

    def begin_trasaction
      raise "Nested transactions are not allowed" if current_transaction
      self.current_transaction = session.create_transaction
    end

    def commit_transaction deadline: 120
      return unless current_transaction

      start_time = Time.now
      backoff = 1.0
      session.commit_transaction current_transaction
    rescue GRPC::Aborted, Google::Cloud::AbortedError => err
      if Time.now - start_time > deadline
        if err.is_a? GRPC::BadStatus
          err = Google::Cloud::Error.from_error err
        end
        raise err
      end
      sleep(delay_from_aborted(err) || backoff *= 1.3)
      retry
    rescue StandardError => err
      rollback_transaction
      return nil if err.is_a? Google::Cloud::Spanner::Rollback
      raise err
    ensure
      self.current_transaction = nil
    end

    def rollback_transaction
      if current_transaction
        session.rollback current_transaction.transaction_id
      end
    ensure
      self.current_transaction = nil
    end

    def transaction_selector
      return unless current_transaction

      Google::Spanner::V1::TransactionSelector.new \
        id: current_transaction.transaction_id
    end

    def snapshot sql, options = {}
      raise "Nested snapshots are not allowed" if current_transaction

      session.snapshot options do |snp|
        snp.execute_query sql
      end
    end

    def truncate table_name
      session.delete table_name
    end

    def self.database_path config
      "#{config[:project]}/#{config[:instance]}/#{config[:database]}"
    end

    private

    ##
    # Retrieves the delay value from Google::Cloud::AbortedError or
    # GRPC::Aborted
    def delay_from_aborted err
      return nil if err.nil?
      if err.respond_to?(:metadata) && err.metadata["retryDelay"]
        seconds = err.metadata["retryDelay"]["seconds"].to_i
        nanos = err.metadata["retryDelay"]["nanos"].to_i
        return seconds if nanos.zero?
        return seconds + (nanos / 1000000000.0)
      end
      # No metadata? Try the inner error
      delay_from_aborted err.cause
    rescue StandardError
      # Any error indicates the backoff should be handled elsewhere
      nil
    end
  end
end
