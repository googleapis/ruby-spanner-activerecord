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

        def exec_query sql, name = "SQL", binds = [], prepare: false
        end

        def truncate _, _
          raise ActiveRecordError, "Truncate table is not supporrted"
        end
      end
    end
  end
end
