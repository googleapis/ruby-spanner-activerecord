# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
        # DDL Statements

        def execute_ddl sql, migration_name: nil
          materialize_transactions

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
              result = @connection.execute_query sql
              ActiveRecord::Result.new(
                result.fields.keys.map(&:to_s), result.rows.map(&:values)
              )
            end
          end
        end

        def query sql, name = nil
          exec_query sql, name
        end

        def exec_query sql, name = "SQL", binds = [], prepare: false
          params = binds.each_with_object({}) do |attribute, result|
            result[attribute.name] = attribute.value_for_database
          end

          log sql, name, binds do
            result = @connection.execute_query sql, params: params
            ActiveRecord::Result.new(
              result.fields.keys.map(&:to_s), result.rows.map(&:values)
            )
          end
        end

        # Transaction

        def begin_db_transaction
          @connection.begin_trasaction
        end

        def commit_db_transaction
          @connection.commit_transaction
        end

        def rollback_db_transaction
          @connection.rollback_transaction
        end
      end
    end
  end
end
