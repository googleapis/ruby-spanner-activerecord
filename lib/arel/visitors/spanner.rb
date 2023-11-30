# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module Arel # :nodoc: all
  module Visitors
    class StalenessHint
      attr_reader :value

      def initialize value
        @value = value
      end
    end

    class StatementHint
      attr_reader :value

      def initialize value
        @value = value
      end
    end

    class Spanner < Arel::Visitors::ToSql
      def compile node, collector = Arel::Collectors::SQLString.new
        collector.class.module_eval { attr_accessor :hints }
        collector.class.module_eval { attr_accessor :table_hints }
        collector.class.module_eval { attr_accessor :join_hints }
        collector.hints = {}
        collector.table_hints = {}
        collector.join_hints = {}

        sql, binds = accept(node, collector).value
        sql = collector.hints[:statement_hint].value + sql if collector.hints[:statement_hint]

        if binds
          binds << collector.hints[:staleness] if collector.hints[:staleness]
          binds << collector.hints[:request_options] if collector.hints[:request_options]
          [sql, binds]
        else
          sql
        end
      end

      private

      BIND_BLOCK = proc { |i| "@p#{i}" }
      private_constant :BIND_BLOCK

      def bind_block
        BIND_BLOCK
      end

      def visit_table_hint v, collector
        value = v.delete_prefix("table_hint:").strip
        # TODO: This does not support FORCE_INDEX hints that reference an index that contains '@{' in the name.
        start_of_hint_index = value.rindex "@{"
        table_name = value[0, start_of_hint_index]
        table_hint = value[start_of_hint_index, value.length]
        collector.table_hints[table_name] = table_hint if table_name && table_hint
      end

      def visit_statement_hint v, collector
        collector.hints[:statement_hint] = \
          StatementHint.new v.delete_prefix("statement_hint:")
      end

      # rubocop:disable Naming/MethodName
      def visit_Arel_Nodes_OptimizerHints o, collector
        o.expr.each do |v|
          visit_table_hint v, collector if v.start_with? "table_hint:"
          visit_statement_hint v, collector if v.start_with? "statement_hint:"
          if v.start_with? "max_staleness:"
            collector.hints[:staleness] = \
              StalenessHint.new max_staleness: v.delete_prefix("max_staleness:").to_f
            next
          end
          if v.start_with? "exact_staleness:"
            collector.hints[:staleness] = \
              StalenessHint.new exact_staleness: v.delete_prefix("exact_staleness:").to_f
            next
          end
          if v.start_with? "min_read_timestamp:"
            time = Time.xmlschema v.delete_prefix("min_read_timestamp:")
            collector.hints[:staleness] = \
              StalenessHint.new min_read_timestamp: time
            next
          end
          next unless v.start_with? "read_timestamp:"
          time = Time.xmlschema v.delete_prefix("read_timestamp:")
          collector.hints[:staleness] = \
            StalenessHint.new read_timestamp: time
        end
        collector
      end

      def visit_Arel_Nodes_Comment o, collector
        o.values.each do |v|
          if v.start_with?("request_tag:") || v.start_with?("transaction_tag:")
            collector.hints[:request_options] ||= \
              Google::Cloud::Spanner::V1::RequestOptions.new
          end

          if v.start_with? "request_tag:"
            collector.hints[:request_options].request_tag = v.delete_prefix("request_tag:").strip
            next
          end
          if v.start_with? "transaction_tag:"
            collector.hints[:request_options].transaction_tag = v.delete_prefix("transaction_tag:").strip
            next
          end
        end
        # Also include the annotations as comments by calling the super implementation.
        super
      end

      def visit_Arel_Table o, collector
        return super unless collector.table_hints[o.name]
        if o.table_alias
          collector << quote_table_name(o.name) << collector.table_hints[o.name] \
                    << " " << quote_table_name(o.table_alias)
        else
          collector << quote_table_name(o.name) << collector.table_hints[o.name]
        end
      end

      # For ActiveRecord 7.0
      def visit_ActiveModel_Attribute o, collector
        # Do not generate a query parameter if the value should be set to the PENDING_COMMIT_TIMESTAMP(), as that is
        # not supported as a parameter value by Cloud Spanner.
        return collector << "PENDING_COMMIT_TIMESTAMP()" \
          if o.type.is_a?(ActiveRecord::Type::Spanner::Time) && o.value == :commit_timestamp
        collector.add_bind(o, &bind_block)
      end

      # For ActiveRecord 6.x
      def visit_Arel_Nodes_BindParam o, collector
        # Do not generate a query parameter if the value should be set to the PENDING_COMMIT_TIMESTAMP(), as that is
        # not supported as a parameter value by Cloud Spanner.
        return collector << "PENDING_COMMIT_TIMESTAMP()" \
            if o.value.respond_to?(:type) \
              && o.value.type.is_a?(ActiveRecord::Type::Spanner::Time) \
              && o.value.value == :commit_timestamp
        collector.add_bind(o.value, &bind_block)
      end
      # rubocop:enable Naming/MethodName
    end
  end
end
