# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module Arel # :nodoc: all
  module Visitors
    class Spanner < Arel::Visitors::ToSql
      def compile node, collector = Arel::Collectors::SQLString.new
        @index = 0
        accept(node, collector).value
      end

      private

      # rubocop:disable Naming/MethodName
      def visit_Arel_Nodes_BindParam o, collector
        # Do not generate a query parameter if the value should be set to the PENDING_COMMIT_TIMESTAMP(), as that is
        # not supported as a parameter value by Cloud Spanner.
        return collector << "PENDING_COMMIT_TIMESTAMP()" \
          if o.value.type.is_a?(ActiveRecord::Type::Spanner::Time) && o.value.value == :commit_timestamp

        @index += 1
        collector.add_bind(o.value) { "@#{o.value.name}_#{@index}" }
      end
      # rubocop:enable Naming/MethodName
    end
  end
end
