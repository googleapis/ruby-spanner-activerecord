# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
        # DDL Statements

        def execute_ddl sql, migration_name: nil
          log sql, "SCHEMA" do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute_ddl sql, operation_id: migration_name
            end
          end
        rescue Google::Cloud::Error => error
          raise ActiveRecord::StatementInvalid, error
        end

        def truncate table_name, name = nil
          Array(table_name).each do |t|
            log "TURNCATE #{t}", name do
              @connection.truncate t
            end
          end
        end

        # DML and DQL Statements

        WRITE_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter
                      .build_read_query_regexp(
                        :insert, :delete, :update, :set
                      )
        private_constant :WRITE_QUERY

        def write_query? sql
          WRITE_QUERY =~ sql
        end

        # Executes the DML/DQL statement in the context of this connection.
        def execute sql, name = nil
          materialize_transactions

          log sql, name do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute_query sql
            end
          end
        end

        def query sql, name = nil
          exec_query sql, name
        end

        def exec_query sql, name = "SQL", binds = [], prepare: false
          result = _exec_query sql, name, binds
          ActiveRecord::Result.new(
            result.fields.keys.map(&:to_s), result.rows.map(&:values)
          )
        end

        def exec_insert sql, name = nil, binds = [], pk = nil, _sequence_name = nil
          sql, binds = sql_for_insert sql, pk, binds
          _exec_query sql, name, binds, transaction_required: true
        end

        def exec_insert_all sql, name
          _exec_query sql, name, transaction_required: true
        end

        def update arel, name = nil, binds = []
          sql, binds = to_sql_and_binds arel, binds
          sql = "#{sql} WHERE true" if arel.ast.wheres.empty?
          exec_update sql, name, binds
        end
        alias delete update

        def exec_update sql, name = "SQL", binds = []
          result = _exec_query sql, name, binds, transaction_required: true
          return result.row_count if result.row_count

          raise ActiveRecord::StatementInvalid.new(
            "DML statement is invalid.", sql
          )
        end
        alias exec_delete exec_update

        # Transaction

        def begin_db_transaction
          log "BEGIN" do
            @connection.begin_trasaction
          end
        end

        def commit_db_transaction
          log "COMMIT" do
            @connection.commit_transaction
          end
        end

        def rollback_db_transaction
          log "ROLLBACK" do
            @connection.rollback_transaction
          end
        end

        private

        def convert_to_params binds
          binds.each_with_object({}) do |attribute, result|
            result[attribute.name] = attribute.value_for_database
          end
        end

        def _exec_query sql, name, binds = [], transaction_required: nil
          materialize_transactions

          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError(
              "Write query attempted while in readonly mode: #{sql}"
            )
          end

          log sql, name, binds do
            @connection.execute_query \
              sql, transaction_required: transaction_required
          end
        end
      end
    end
  end
end
