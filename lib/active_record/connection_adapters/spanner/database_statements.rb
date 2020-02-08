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

        WRITE_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :insert, :delete, :update, :set
        )

        def write_query? sql
          WRITE_QUERY.match? sql
        end

        # Executes the SQL statement in the context of this connection.
        def execute sql, name = nil
          materialize_transactions

          log sql, name do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.exec_query sql
            end
          end
        end

        def query sql, name = nil
          exec_query sql, name
        end

        def exec_query sql, name = "SQL", binds = [], prepare: false
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError(
              "Write query attempted while in readonly mode: #{sql}"
            )
          end

          log sql, name, binds do
            result = @connection.execute_query(
              sql, params: convert_to_params(binds)
            )
            ActiveRecord::Result.new(
              result.fields.keys.map(&:to_s), result.rows.map(&:values)
            )
          end
        end

        def exec_delete sql, name = "SQL", binds = []
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError(
              "Write query attempted while in readonly mode: #{sql}"
            )
          end

          log sql, name, binds do
            @connection.execute_delete sql, params: convert_to_params(binds)
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

        private

        def convert_to_params binds
          binds.each_with_object({}) do |attribute, result|
            result[attribute.name] = attribute.value_for_database
          end
        end
      end
    end
  end
end
