# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "google/cloud/spanner"
require "spanner_client_ext"
require "activerecord_spanner_adapter/information_schema"

module ActiveRecordSpannerAdapter
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
        @spanners[database_path(config)] ||= Google::Cloud::Spanner.new(
          project_id: config[:project],
          credentials: config[:credentials],
          emulator_host: config[:emulator_host],
          scope: config[:scope],
          timeout: config[:timeout],
          lib_name: "spanner-activerecord-adapter",
          lib_version: ActiveRecordSpannerAdapter::VERSION
        )
      end
    end

    def self.information_schema config
      @information_schemas ||= {}
      @information_schemas[database_path(config)] ||= \
        ActiveRecordSpannerAdapter::InformationSchema.new new(config)
    end

    def session
      @last_used = Time.current
      @session ||= spanner.create_session instance_id, database_id
    end
    alias connect! session

    def active?
      # This method should not initialize a session.
      unless @session
        return false
      end
      # Assume that it is still active if it has been used in the past 50 minutes.
      if ((Time.current - @last_used) / 60).round < 50
        return true
      end
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

    # DDL Statements

    # @params [Array<String>, String] sql Single or list of statements
    def execute_ddl statements, operation_id: nil, wait_until_done: true
      statements = Array statements
      return unless statements.any?

      # If a DDL batch is active we only buffer the statements on the connection until the batch is run.
      if @ddl_batch
        @ddl_batch.push(*statements)
        return true
      end

      execute_ddl_statements statements, operation_id, wait_until_done
    end

    # DDL Batching

    ##
    # Executes a set of DDL statements as one batch. This method raises an error if no block is given.
    #
    # @example
    #   connection.ddl_batch do
    #     connection.execute_ddl "CREATE TABLE `Users` (Id INT64, Name STRING(MAX)) PRIMARY KEY (Id)"
    #     connection.execute_ddl "CREATE INDEX Idx_Users_Name ON `Users` (Name)"
    #   end
    def ddl_batch
      raise Google::Cloud::FailedPreconditionError, "No block given for the DDL batch" unless block_given?
      begin
        start_batch_ddl
        yield
        run_batch
      rescue StandardError
        abort_batch
        raise
      end
    end

    ##
    # Starts a manual DDL batch. The batch must be ended by calling either run_batch or abort_batch.
    #
    # @example
    #   begin
    #     connection.start_batch_ddl
    #     connection.execute_ddl "CREATE TABLE `Users` (Id INT64, Name STRING(MAX)) PRIMARY KEY (Id)"
    #     connection.execute_ddl "CREATE INDEX Idx_Users_Name ON `Users` (Name)"
    #     connection.run_batch
    #   rescue StandardError
    #     connection.abort_batch
    #     raise
    #   end
    def start_batch_ddl
      if @ddl_batch
        raise Google::Cloud::FailedPreconditionError, "A DDL batch is already active on this connection"
      end
      @ddl_batch = []
    end

    ##
    # Aborts the current batch on this connection. This is a no-op if there is no batch on this connection.
    #
    # @see start_batch_ddl
    def abort_batch
      @ddl_batch = nil
    end

    ##
    # Runs the current batch on this connection. This will raise a FailedPreconditionError if there is no
    # active batch on this connection.
    #
    # @see start_batch_ddl
    def run_batch
      unless @ddl_batch
        raise Google::Cloud::FailedPreconditionError, "There is no batch active on this connection"
      end
      # Just return if the batch is empty.
      return true if @ddl_batch.empty?
      begin
        execute_ddl_statements @ddl_batch, nil, true
      ensure
        @ddl_batch = nil
      end
    end

    # DQL, DML Statements

    def execute_query sql, params: nil, types: nil, transaction_required: nil
      if params
        converted_params, types = \
          Google::Cloud::Spanner::Convert.to_input_params_and_types(
            params, types
          )
      end

      if transaction_required && !current_transaction&.active?
        transaction = begin_transaction
      end

      session.execute_query \
        sql,
        params: converted_params,
        types: types,
        transaction: transaction_selector,
        seqno: (current_transaction&.next_sequence_number)
    rescue Google::Cloud::AbortedError
      # Mark the current transaction as aborted to prevent any unnecessary further requests on the transaction.
      current_transaction&.mark_aborted
      raise
    rescue Google::Cloud::NotFoundError
      # Session is idle for too long then it will throw an error not found.
      # In this case reset and retry.
      reset!
      retry
    ensure
      commit_transaction if transaction
    end

    # Transactions

    def begin_transaction
      self.current_transaction = Transaction.new self
      current_transaction.begin
    end

    def commit_transaction
      return unless current_transaction
      current_transaction.commit
    end

    def rollback_transaction
      return unless current_transaction
      current_transaction.rollback
    end

    def transaction_selector
      return current_transaction&.transaction_selector if current_transaction&.active?
    end

    def snapshot sql, _options = {}
      raise "Nested snapshots are not allowed" if current_transaction

      session.snapshot do |snp|
        snp.execute_query sql
      end
    rescue Google::Cloud::UnavailableError
      retry
    end

    def truncate table_name
      session.delete table_name
    end

    def self.database_path config
      "#{config[:emulator_host]}/#{config[:project]}/#{config[:instance]}/#{config[:database]}"
    end

    private

    def execute_ddl_statements statements, operation_id, wait_until_done
      job = database.update statements: statements, operation_id: operation_id
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.done?
    end
  end
end
