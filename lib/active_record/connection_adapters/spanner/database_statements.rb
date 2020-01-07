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
              @connection.execute_query(sql).rows
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

        def execute_ddl sql
          job = spanner_database.update statements: [sql]
          job.wait_until_done!
          return job unless job.error?

          raise Google::Cloud::Error.from_error job.error if job.error?
        rescue Google::Cloud::Error => error
          raise ActiveRecord::StatementInvalid, error
        end

        def truncate _, _
          raise ActiveRecordError, "Truncate table is not supported"
        end
      end
    end
  end
end
