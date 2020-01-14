module SpannerActiverecord
  class Index
    class Column
      attr_reader :table_name, :index_name, :name, :order, :ordinal_position

      def initialize \
          connection,
          table_name,
          index_name,
          name,
          order: nil,
          ordinal_position: nil
        @connection = connection
        @table_name = table_name
        @index_name = index_name
        @name = name
        @order = order.to_s.upcase if order
        @ordinal_position = ordinal_position
      end

      def storing?
        @ordinal_position.nil?
      end

      def desc?
        @order == "DESC"
      end

      def desc!
        @order = "DESC"
      end
    end
  end
end
