# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
        # DDL, DML and DQL Statements

        def execute sql, name = nil
          statement_type = sql_statement_type sql

          if preventing_writes? && statement_type == :dml
            raise ActiveRecord::ReadOnlyError(
              "Write query attempted while in readonly mode: #{sql}"
            )
          end

          if statement_type == :ddl
            @connection.ddl_statements << sql
            return
          end

          transaction_required = statement_type == :dml
          materialize_transactions

          log sql, name do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute_query(
                sql,
                transaction_required: transaction_required
              )
            end
          end
        end

        def query sql, name = nil
          exec_query sql, name
        end

        def exec_query sql, name = "SQL", _binds = [], prepare: false # rubocop:disable Lint/UnusedMethodArgument
          result = execute sql, name
          ActiveRecord::Result.new(
            result.fields.keys.map(&:to_s), result.rows.map(&:values)
          )
        end

        def update arel, name = nil, binds = []
          sql, binds = to_sql_and_binds arel, binds
          sql = "#{sql} WHERE true" if arel.ast.wheres.empty?
          exec_update sql, name, binds
        end
        alias delete update

        def exec_update sql, name = "SQL", _binds = []
          result = execute sql, name
          return result.row_count if result.row_count

          raise ActiveRecord::StatementInvalid.new(
            "DML statement is invalid.", sql
          )
        end
        alias exec_delete exec_update

        def truncate table_name, name = nil
          Array(table_name).each do |t|
            log "TURNCATE #{t}", name do
              @connection.truncate t
            end
          end
        end

        def write_query? sql
          sql_statement_type(sql) == :dml
        end

        def execute_ddl statements
          log "MIGRATION", "SCHEMA" do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute_ddl statements
            end
          end
        rescue Google::Cloud::Error => error
          raise ActiveRecord::StatementInvalid, error
        end

        # Transaction

        def begin_db_transaction
          log "BEGIN" do
            @connection.begin_transaction
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

        DDL_REGX = ActiveRecord::ConnectionAdapters::AbstractAdapter
                   .build_read_query_regexp(:create, :alter, :drop).freeze

        DML_REGX = ActiveRecord::ConnectionAdapters::AbstractAdapter
                   .build_read_query_regexp(:insert, :delete, :update).freeze

        def sql_statement_type sql
          case sql
          when DDL_REGX
            :ddl
          when DML_REGX
            :dml
          else
            :dql
          end
        end
      end
    end
  end
end
