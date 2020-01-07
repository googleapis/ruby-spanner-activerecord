# frozen_string_literal: true

# NOTE: Not required as of now

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
      end

      class IndexDefinition
        attr_reader :table, :name, :unique, :columns, :orders
        attr_reader :null_filtered, :storing, :interleve_in

        def initialize \
            table,
            name,
            unique = false,
            columns = [],
            orders: {},
            null_filtered: nil,
            storing: nil,
            interleve_in: nil
          @table = table
          @name = name
          @unique = unique
          @columns = columns
          @orders = orders
          @null_filtered = null_filtered
          @storing = storing
          @interleve_in = interleve_in
        end
      end
    end
  end
end
