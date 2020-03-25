module Arel # :nodoc: all
  module Visitors
    class Spanner < Arel::Visitors::ToSql
      private

      # rubocop:disable Naming/MethodName
      def visit_Arel_Nodes_BindParam o, collector
        collector.add_bind(o.value) { "@#{o.value.name}" }
      end
      # rubocop:enable Naming/MethodName
    end
  end
end
