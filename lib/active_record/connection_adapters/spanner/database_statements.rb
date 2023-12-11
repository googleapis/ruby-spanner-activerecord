# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "active_record/gem_version"

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module DatabaseStatements
        VERSION_7_1_0 = Gem::Version.create "7.1.0"

        # DDL, DML and DQL Statements

        def execute sql, name = nil, binds = []
          internal_execute sql, name, binds
        end

        def internal_exec_query sql, name = "SQL", binds = [], prepare: false, async: false
          result = internal_execute sql, name, binds, prepare: prepare, async: async
          ActiveRecord::Result.new(
            result.fields.keys.map(&:to_s), result.rows.map(&:values)
          )
        end

        def internal_execute sql, name = "SQL", binds = [],
                             prepare: false, async: false # rubocop:disable Lint/UnusedMethodArgument
          statement_type = sql_statement_type sql

          if preventing_writes? && [:dml, :ddl].include?(statement_type)
            raise ActiveRecord::ReadOnlyError(
              "Write query attempted while in readonly mode: #{sql}"
            )
          end

          if statement_type == :ddl
            execute_ddl sql
          else
            transaction_required = statement_type == :dml
            materialize_transactions

            # First process and remove any hints in the binds that indicate that
            # a different read staleness should be used than the default.
            staleness_hint = binds.find { |b| b.is_a? Arel::Visitors::StalenessHint }
            if staleness_hint
              selector = Google::Cloud::Spanner::Session.single_use_transaction staleness_hint.value
              binds.delete staleness_hint
            end
            request_options = binds.find { |b| b.is_a? Google::Cloud::Spanner::V1::RequestOptions }
            if request_options
              binds.delete request_options
            end

            log_args = [sql, name]
            log_args.concat [binds, type_casted_binds(binds)] if log_statement_binds

            log(*log_args) do
              types, params = to_types_and_params binds
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                if transaction_required
                  transaction do
                    @connection.execute_query sql, params: params, types: types, request_options: request_options
                  end
                else
                  @connection.execute_query sql, params: params, types: types, single_use_selector: selector,
                                            request_options: request_options
                end
              end
            end
          end
        end

        # The method signatures for executing queries and DML statements changed between Rails 7.0 and 7.1.

        if ActiveRecord.gem_version >= VERSION_7_1_0
          def sql_for_insert sql, pk, binds, returning
            if supports_insert_returning?
              if pk && !_has_pk_binding(pk, binds)
                returning ||= []
                returning |= if pk.respond_to? :each
                               pk
                             else
                               [pk]
                             end
              end
              if returning&.any?
                returning_columns_statement = returning.map { |c| quote_column_name c }.join(", ")
                sql = "#{sql} THEN RETURN #{returning_columns_statement}"
              end
            end

            [sql, binds]
          end

          def query sql, name = nil
            exec_query sql, name
          end
        else # ActiveRecord.gem_version < VERSION_7_1_0
          def query sql, name = nil
            exec_query sql, name
          end

          def exec_query sql, name = "SQL", binds = [], prepare: false # rubocop:disable Lint/UnusedMethodArgument
            result = execute sql, name, binds
            ActiveRecord::Result.new(
              result.fields.keys.map(&:to_s), result.rows.map(&:values)
            )
          end

          def sql_for_insert sql, pk, binds
            if pk && !_has_pk_binding(pk, binds)
              returning_columns_statement = if pk.respond_to? :each
                                              pk.map { |c| quote_column_name c }.join(", ")
                                            else
                                              quote_column_name pk
                                            end
              sql = "#{sql} THEN RETURN #{returning_columns_statement}" if returning_columns_statement
            end
            super
          end
        end # ActiveRecord.gem_version < VERSION_7_1_0

        def _has_pk_binding pk, binds
          if pk.respond_to? :each
            has_value = true
            pk.each { |col| has_value &&= binds.any? { |bind| bind.name == col } }
            has_value
          else
            binds.any? { |bind| bind.name == pk }
          end
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
        # isolation level :serializable, but also defines three additional 'isolation levels' that can be used
        # to start specific types of Spanner transactions:
        # * :read_only: Starts a read-only snapshot transaction using a strong timestamp bound.
        # * :buffered_mutations: Starts a read/write transaction that will use mutations instead of DML for single-row
        #                        inserts/updates/deletes. Mutations are buffered locally until the transaction is
        #                        committed, and any changes during a transaction cannot be read by the application.
        # * :pdml: Starts a Partitioned DML transaction. Executing multiple DML statements in one PDML transaction
        #          block is NOT supported A PDML transaction is not guaranteed to be atomic.
        #          See https://cloud.google.com/spanner/docs/dml-partitioned for more information.
        #
        # In addition to the above, a Hash containing read-only snapshot options may be used to start a specific
        # read-only snapshot:
        # * { timestamp: Time } Starts a read-only snapshot at the given timestamp.
        # * { staleness: Integer } Starts a read-only snapshot with the given staleness in seconds.
        # * { strong: <any value>} Starts a read-only snapshot with strong timestamp bound
        #                          (this is the same as :read_only)
        #
        def begin_isolated_db_transaction isolation
          if isolation.is_a? Hash
            raise "Unsupported isolation level: #{isolation}" unless \
              isolation[:timestamp] || isolation[:staleness] || isolation[:strong]
            raise "Only one option is supported. It must be one of `timestamp`, `staleness` or `strong`." \
              if isolation.count != 1
          else
            raise "Unsupported isolation level: #{isolation}" unless \
              [:serializable, :read_only, :buffered_mutations, :pdml].include? isolation
          end

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
            if bind.respond_to? :type
              type = ActiveRecord::Type::Spanner::SpannerActiveRecordConverter
                     .convert_active_model_type_to_spanner(bind.type)
            elsif bind.class == Symbol
              # This ensures that for example :environment is sent as the string 'environment' to Cloud Spanner.
              type = :STRING
            end
            [
              # Generates binds for named parameters in the format `@p1, @p2, ...`
              "p#{i + 1}", type
            ]
          end.to_h
          params = binds.enum_for(:each_with_index).map do |bind, i|
            type = if bind.respond_to? :type
                     bind.type
                   elsif bind.class == Symbol
                     # This ensures that for example :environment is sent as the string 'environment' to Cloud Spanner.
                     :STRING
                   else
                     # The Cloud Spanner default type is INT64 if no other type is known.
                     ActiveModel::Type::Integer
                   end
            bind_value = bind.respond_to?(:value) ? bind.value : bind
            value = ActiveRecord::Type::Spanner::SpannerActiveRecordConverter
                    .serialize_with_transaction_isolation_level(type, bind_value, :dml)

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
          table_name = arel.ast.relation.name if arel.ast.relation.is_a? Arel::Table
          table_name = arel.ast.relation.left.name if arel.ast.relation.is_a? Arel::Nodes::JoinSource
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

        COMMENT_REGEX = %r{(?:--.*\n)*|/\*(?:[^*]|\*[^/])*\*/}m.freeze \
            unless defined? ActiveRecord::ConnectionAdapters::AbstractAdapter::COMMENT_REGEX
        COMMENT_REGEX = ActiveRecord::ConnectionAdapters::AbstractAdapter::COMMENT_REGEX \
            if defined? ActiveRecord::ConnectionAdapters::AbstractAdapter::COMMENT_REGEX

        private_class_method def self.build_sql_statement_regexp *parts # :nodoc:
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
