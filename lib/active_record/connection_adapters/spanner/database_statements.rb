# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
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

        # TODO: Implement to fetch data with prepared statements.
        def exec_query sql, name = "SQL", binds = [], prepare: false
          ActiveRecord::Result.new [], []
        end

        def truncate _table_name, _name = nil
          raise ActiveRecordError, "Truncate table is not supported"
        end

        # DDL Statements

        def execute_ddl sql, migration_name: nil
          log sql do
            @connection.execute_ddl sql, operation_id: migration_name
          end
        rescue Google::Cloud::Error => error
          raise ActiveRecord::StatementInvalid, error
        end
      end
    end
  end
end
