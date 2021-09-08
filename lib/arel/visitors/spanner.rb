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

    class Spanner < Arel::Visitors::ToSql
      def compile node, collector = Arel::Collectors::SQLString.new
        collector.class.module_eval { attr_accessor :hints }
        collector.hints = {}
        sql, binds = accept(node, collector).value
        binds << collector.hints[:staleness] if collector.hints[:staleness]
        [sql, binds]
      end

      private

      BIND_BLOCK = proc { |i| "@p#{i}" }
      private_constant :BIND_BLOCK

      def bind_block
        BIND_BLOCK
      end

      # rubocop:disable Naming/MethodName
      def visit_Arel_Nodes_OptimizerHints o, collector
        o.expr.each do |v|
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

      def visit_Arel_Nodes_BindParam o, collector
        # Do not generate a query parameter if the value should be set to the PENDING_COMMIT_TIMESTAMP(), as that is
        # not supported as a parameter value by Cloud Spanner.
        return collector << "PENDING_COMMIT_TIMESTAMP()" \
          if o.value.type.is_a?(ActiveRecord::Type::Spanner::Time) && o.value.value == :commit_timestamp
        collector.add_bind(o.value, &bind_block)
      end
      # rubocop:enable Naming/MethodName
    end
  end
end
