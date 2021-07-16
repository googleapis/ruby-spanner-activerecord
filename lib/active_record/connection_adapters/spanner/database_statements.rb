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

        def execute sql, name = nil, binds = []
          statement_type = sql_statement_type sql

          if preventing_writes? && (statement_type == :dml || statement_type == :ddl)
            raise ActiveRecord::ReadOnlyError(
              "Write query attempted while in readonly mode: #{sql}"
            )
          end

          if statement_type == :ddl
            execute_ddl sql
          else
            transaction_required = statement_type == :dml
            materialize_transactions

            log sql, name do
              types, params = to_types_and_params binds
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                if transaction_required
                  transaction do
                    @connection.execute_query sql, params: params, types: types
                  end
                else
                  @connection.execute_query sql, params: params, types: types
                end
              end
            end
          end
        end

        def query sql, name = nil
          exec_query sql, name
        end

        def exec_query sql, name = "SQL", binds = [], prepare: false # rubocop:disable Lint/UnusedMethodArgument
          result = execute sql, name, binds
          ActiveRecord::Result.new(
            result.fields.keys.map(&:to_s), result.rows.map(&:values)
          )
        end

        def exec_mutation mutation
          @connection.current_transaction.buffer mutation
        end

        def update arel, name = nil, binds = []
          # Add a `WHERE TRUE` if it is an update_all or delete_all call that uses DML.
          if !should_use_mutation(arel) && arel.respond_to?(:ast) && arel.ast.wheres.empty?
            arel.ast.wheres << Arel::Nodes::SqlLiteral.new("TRUE")
          end
          return super unless should_use_mutation arel

          raise "Unsupported update for use with mutations: #{arel}" unless arel.is_a? Arel::DeleteManager

          exec_mutation create_delete_all_mutation arel if arel.is_a? Arel::DeleteManager
          0 # Affected rows (unknown)
        end
        alias delete update

        def exec_update sql, name = "SQL", binds = []
          result = execute sql, name, binds
          # Make sure that we consume the entire result stream before trying to get the stats.
          # This is required because the ExecuteStreamingSql RPC is also used for (Partitioned) DML,
          # and this RPC can return multiple partial result sets for DML as well. Only the last partial
          # result set will contain the statistics. Although there will never be any rows, this makes
          # sure that the stream is fully consumed.
          result.rows.each { |_| }
          return result.row_count if result.row_count

          raise ActiveRecord::StatementInvalid.new(
            "DML statement is invalid.", sql: sql
          )
        end
        alias exec_delete exec_update

        def truncate table_name, name = nil
          Array(table_name).each do |t|
            log "TRUNCATE #{t}", name do
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

        def transaction requires_new: nil, isolation: nil, joinable: true
          if !requires_new && current_transaction.joinable?
            return super
          end

          backoff = 0.2
          begin
            super
          rescue ActiveRecord::StatementInvalid => err
            if err.cause.is_a? Google::Cloud::AbortedError
              sleep(delay_from_aborted(err) || backoff *= 1.3)
              retry
            end
            raise
          end
        end

        def transaction_isolation_levels
          {
            read_uncommitted:   "READ UNCOMMITTED",
            read_committed:     "READ COMMITTED",
            repeatable_read:    "REPEATABLE READ",
            serializable:       "SERIALIZABLE",

            # These are not really isolation levels, but it is the only (best) way to pass in additional
            # transaction options to the connection.
            read_only:          "READ_ONLY",
            buffered_mutations: "BUFFERED_MUTATIONS"
          }
        end

        def begin_db_transaction
          log "BEGIN" do
            @connection.begin_transaction
          end
        end

        # Begins a transaction on the database with the specified isolation level. Cloud Spanner only supports
        # isolation level :serializable, but also defines two additional 'isolation levels' that can be used
        # to start specific types of Spanner transactions:
        # * :read_only: Starts a read-only snapshot transaction using a strong timestamp bound.
        # * :buffered_mutations: Starts a read/write transaction that will use mutations instead of DML for single-row
        #                        inserts/updates/deletes. Mutations are buffered locally until the transaction is
        #                        committed, and any changes during a transaction cannot be read by the application.
        # * :pdml: Starts a Partitioned DML transaction. Executing multiple DML statements in one PDML transaction
        #          block is NOT supported A PDML transaction is not guaranteed to be atomic.
        #          See https://cloud.google.com/spanner/docs/dml-partitioned for more information.
        def begin_isolated_db_transaction isolation
          raise "Unsupported isolation level: #{isolation}" unless \
              [:serializable, :read_only, :buffered_mutations, :pdml].include? isolation

          log "BEGIN #{isolation}" do
            @connection.begin_transaction isolation
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

        # Translates binds to Spanner types and params.
        def to_types_and_params binds
          types = binds.enum_for(:each_with_index).map do |bind, i|
            type = :INT64
            if bind.respond_to?(:type)
              type = ActiveRecord::Type::Spanner::SpannerActiveRecordConverter
                       .convert_active_model_type_to_spanner(bind.type)
            end
            [
              # "#{bind.name}_#{i + 1}",
              "p#{i + 1}", type
            ]
          end.to_h
          params = binds.enum_for(:each_with_index).map do |bind, i|
            type = bind.respond_to?(:type) ? bind.type : ActiveModel::Type::Integer
            if type.respond_to?(:serialize)
              value = type.method(:serialize).arity < 0 ? type.serialize(bind.value, :dml) : type.serialize(bind.value)
            else
              value = bind
            end

            # ["#{v.name}_#{i + 1}", value]
            ["p#{i + 1}", value]
          end.to_h
          [types, params]
        end

        # An insert/update/delete statement could use mutations in some specific circumstances.
        # This method returns an indication whether a specific operation should use mutations instead of DML
        # based on the operation itself, and the current transaction.
        def should_use_mutation arel
          !@connection.current_transaction.nil? \
            && @connection.current_transaction.isolation == :buffered_mutations \
            && can_use_mutation(arel) \
        end

        def can_use_mutation arel
          return true if arel.is_a?(Arel::DeleteManager) && arel.respond_to?(:ast) && arel.ast.wheres.empty?
          false
        end

        def create_delete_all_mutation arel
          unless arel.is_a? Arel::DeleteManager
            raise "A delete mutation can only be created from a DeleteManager"
          end
          # Check if it is a delete_all operation.
          unless arel.ast.wheres.empty?
            raise "A delete mutation can only be created without a WHERE clause"
          end
          table_name = arel.ast.relation.name if arel.ast.relation.is_a?(Arel::Table)
          table_name = arel.ast.relation.left.name if arel.ast.relation.is_a?(Arel::Nodes::JoinSource)
          unless table_name
            raise "Could not find table for delete mutation"
          end

          Google::Cloud::Spanner::V1::Mutation.new(
            delete: Google::Cloud::Spanner::V1::Mutation::Delete.new(
              table: table_name,
              key_set: { all: true }
            )
          )
        end

        if defined? ActiveRecord::ConnectionAdapters::AbstractAdapter::COMMENT_REGEX
          COMMENT_REGEX = ActiveRecord::ConnectionAdapters::AbstractAdapter::COMMENT_REGEX
        else
          COMMENT_REGEX = %r{(?:--.*\n)*|/\*(?:[^*]|\*[^/])*\*/}m
        end

        def self.build_sql_statement_regexp(*parts) # :nodoc:
          parts = parts.map { |part| /#{part}/i }
          /\A(?:[\(\s]|#{COMMENT_REGEX})*#{Regexp.union(*parts)}/
        end

        DDL_REGX = build_sql_statement_regexp(:create, :alter, :drop).freeze

        DML_REGX = build_sql_statement_regexp(:insert, :delete, :update).freeze

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

        ##
        # Retrieves the delay value from Google::Cloud::AbortedError or
        # GRPC::Aborted
        def delay_from_aborted err
          return nil if err.nil?
          if err.respond_to?(:metadata) && err.metadata["google.rpc.retryinfo-bin"]
            retry_info = Google::Rpc::RetryInfo.decode err.metadata["google.rpc.retryinfo-bin"]
            seconds = retry_info["retry_delay"].seconds
            nanos = retry_info["retry_delay"].nanos
            return seconds if nanos.zero?
            return seconds + (nanos / 1_000_000_000.0)
          end
          # No metadata? Try the inner error
          delay_from_aborted err.cause
        rescue StandardError
          # Any error indicates the backoff should be handled elsewhere
          nil
        end
      end
    end
  end
end
