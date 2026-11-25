# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module Arel # :nodoc: all
  module Collectors
    class SQLString
      attr_accessor :hints
      attr_accessor :table_hints
      attr_accessor :join_hints
    end
  end

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
        unless collector.respond_to? :hints=
          collector.class.attr_accessor :hints, :table_hints, :join_hints
        end
        collector.hints = {}
        collector.table_hints = {}
        collector.join_hints = {}

        sql, binds = accept(node, collector).value
        sql = collector.hints[:statement_hint].value + sql if collector.hints[:statement_hint]

        if binds
          compile_with_binds collector, sql, binds
        else
          sql
        end
      end

      private

      def compile_with_binds collector, sql, binds
        binds << collector.hints[:staleness] if collector.hints[:staleness]
        binds << collector.hints[:request_options] if collector.hints[:request_options]
        [sql, binds]
      end

      BIND_BLOCK = proc { |i| "@p#{i}" }
      private_constant :BIND_BLOCK

      def bind_block
        BIND_BLOCK
      end

      # TODO: Replace these regexes with a simple lexical parser/scanner for GoogleSQL
      # optimizer hints (handling quoted identifiers, triple-quoted/raw strings, comments,
      # and balanced @{...} blocks reliably without regex limitations).
      HINT_KEY_REGX = /[A-Za-z_][A-Za-z0-9_.]*/
      HINT_VALUE_REGX = /
        '(?>[^'\\\n\r]|\\[^\n\r])*' |
        "(?>[^"\\\n\r]|\\[^\n\r])*" |
        `(?>[^`\\\n\r]|\\[^\n\r])*` |
        #{HINT_KEY_REGX} |
        -?(?>\d+(?>\.\d*)?|\.\d+)(?>[eE][+-]?\d+)?
      /x
      HINT_ENTRY_REGX = /#{HINT_KEY_REGX}\s*=\s*#{HINT_VALUE_REGX}/
      HINT_BLOCK_REGX = /\A@\{\s*#{HINT_ENTRY_REGX}(?:\s*,\s*#{HINT_ENTRY_REGX})*\s*\}\z/
      private_constant :HINT_KEY_REGX, :HINT_VALUE_REGX, :HINT_ENTRY_REGX, :HINT_BLOCK_REGX

      def visit_table_hint hint, collector
        value = hint.delete_prefix("table_hint:").strip
        start_of_hint_index = value.index "@{"
        unless start_of_hint_index&.positive? && value.end_with?("}")
          raise ArgumentError, "Invalid Spanner table hint: #{hint.inspect}"
        end

        table_name = value[0, start_of_hint_index].rstrip
        table_hint = value[start_of_hint_index, value.length]
        unless HINT_BLOCK_REGX.match? table_hint
          raise ArgumentError, "Invalid Spanner table hint: #{hint.inspect}"
        end

        collector.table_hints[table_name] = table_hint
      end

      def visit_statement_hint hint, collector
        raw_hint = hint.delete_prefix "statement_hint:"
        stripped_hint = raw_hint.strip
        unless HINT_BLOCK_REGX.match? stripped_hint
          raise ArgumentError, "Invalid Spanner statement hint: #{hint.inspect}"
        end

        formatted_hint = raw_hint.start_with?(/\s/) ? " #{stripped_hint}" : stripped_hint
        collector.hints[:statement_hint] = StatementHint.new formatted_hint
      end

      # rubocop:disable Naming/MethodName, Metrics/AbcSize
      def visit_Arel_Nodes_OptimizerHints o, collector
        o.expr.each do |v|
          visit_table_hint v, collector if v.start_with? "table_hint:"
          visit_statement_hint v, collector if v.start_with? "statement_hint:"
          if v.start_with? "max_staleness:"
            collector.hints[:staleness] =
              StalenessHint.new max_staleness: v.delete_prefix("max_staleness:").to_f
            next
          end
          if v.start_with? "exact_staleness:"
            collector.hints[:staleness] =
              StalenessHint.new exact_staleness: v.delete_prefix("exact_staleness:").to_f
            next
          end
          if v.start_with? "min_read_timestamp:"
            time = Time.xmlschema v.delete_prefix("min_read_timestamp:")
            collector.hints[:staleness] =
              StalenessHint.new min_read_timestamp: time
            next
          end
          if v.start_with? "read_timestamp:"
            time = Time.xmlschema v.delete_prefix("read_timestamp:")
            collector.hints[:staleness] =
              StalenessHint.new read_timestamp: time
            next
          end
          next unless v.start_with? "priority:"
          priority = v.delete_prefix("priority:").strip.to_sym
          collector.hints[:request_options] ||=
            Google::Cloud::Spanner::V1::RequestOptions.new
          collector.hints[:request_options].priority = priority
        end
        collector
      end
      # rubocop:enable Metrics/AbcSize

      def visit_Arel_Nodes_Comment o, collector
        o.values.each do |v| # rubocop:disable Style/HashEachMethods
          if v.start_with?("request_tag:") || v.start_with?("transaction_tag:")
            collector.hints[:request_options] ||=
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

      # For ActiveRecord 7.1+
      def visit_ActiveModel_Attribute o, collector
        # Do not generate a query parameter if the value should be set to the PENDING_COMMIT_TIMESTAMP(), as that is
        # not supported as a parameter value by Cloud Spanner.
        return collector << "PENDING_COMMIT_TIMESTAMP()" \
          if o.type.is_a?(ActiveRecord::Type::Spanner::Time) && o.value == :commit_timestamp
        collector.add_bind(o, &bind_block)
      end
      # rubocop:enable Naming/MethodName
    end
  end
end
