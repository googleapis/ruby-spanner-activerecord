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
    attr_reader :instance_id, :database_id, :spanner, :ddl_statements
    attr_accessor :current_transaction

    def initialize config
      @instance_id = config[:instance]
      @database_id = config[:database]
      @spanner = self.class.spanners config
      @ddl_statements = []
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

      job = database.update statements: statements, operation_id: operation_id
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.done?
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
        transaction = begin_transaction
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

    def begin_transaction
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
    rescue Google::Cloud::FailedPreconditionError => err
      raise err
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
