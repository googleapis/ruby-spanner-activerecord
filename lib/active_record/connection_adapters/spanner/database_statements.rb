# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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

          execute_pending_ddl

          transaction_required = statement_type == :dml
          materialize_transactions

          log sql, name do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute_query(
                sql,
                transaction_required: (statement_type == :dml)
              )
            end
          end
        end

        def query sql, name = nil
          exec_query sql, name
        end

        def exec_query sql, name = "SQL", _binds = [], prepare: false
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

        def execute_pending_ddl
          return if @connection.ddl_statements.empty?

          execute_ddl @connection.ddl_statements
          @connection.ddl_statements.clear
        end

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
