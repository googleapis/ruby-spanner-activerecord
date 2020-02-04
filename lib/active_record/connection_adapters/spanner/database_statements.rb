# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
        # DDL Statements

        def execute_ddl sql, migration_name: nil
          log sql, "SCHEMA" do
            @connection.execute_ddl sql, operation_id: migration_name
          end
        rescue Google::Cloud::Error => error
          raise ActiveRecord::StatementInvalid, error
        end

        def truncate _table_name, _name = nil
          raise ActiveRecordError, "Truncate table is not supported"
        end

        # DML and DQL Statements

        # Executes the SQL statement in the context of this connection.
        def execute sql, name = nil
          materialize_transactions

          log sql, name do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute_query sql
            end
          end
        end

        def query sql, name = nil
          execute sql, name
        end

        def exec_query sql, name = "SQL", binds = [], prepare: false
          ActiveRecord::Result.new [], []
        end

        def exec_insert sql, name = nil, binds = [], pk = nil, sequence_name = nil
          params = binds.each_with_object({}) do |attribute, result|
            result[attribute.name] = attribute.value_for_database
          end

          # TODO : Get current session for client session pool
          # and execute transection with the current sessions and use use transection
          # method.

          log sql, name, binds do
            @connection.client.transaction do |tx|
              tx.execute_query sql, params: params
            end
          end
        end

        # Transaction

        # TODO : Support lazy transactions
        def transaction requires_new: nil, isolation: nil, joinable: true, &block
          yield
          # @connection.client.transaction(&block)
        end

        def begin_db_transaction
        end

        def commit_db_transaction
        end

        def rollback_db_transaction
        end
      end
    end
  end
end
