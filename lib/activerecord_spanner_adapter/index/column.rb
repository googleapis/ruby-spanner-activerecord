# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecordSpannerAdapter
  class Index
    class Column
      attr_accessor :table_name, :schema_name, :index_name, :name, :order, :ordinal_position

      def initialize \
          table_name,
          index_name,
          name,
          schema_name: "",
          order: nil,
          ordinal_position: nil
        @table_name = table_name.to_s
        @index_name = index_name.to_s
        @schema_name = schema_name.to_s
        @name = name.to_s
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
