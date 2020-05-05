# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    module Spanner
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def interleave_in
          @options[:interleave_in] if @options
        end

        def on_delete
          @options[:on_delete] if @options
        end

        def references *args, **options
          args.each do |ref_name|
            Spanner::ReferenceDefinition.new(ref_name, options).add_to(self)
          end
        end
        alias belongs_to references
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        def primary_key name, type = :primary_key, **options
          type = :string
          options.merge primary_key: true
          super
        end
      end

      DropTableDefinition = Struct.new :name, :options
      DropColumnDefinition = Struct.new :table_name, :name
      ChangeColumnDefinition = Struct.new :table_name, :column, :name
      DropIndexDefinition = Struct.new :name

      class ReferenceDefinition < ActiveRecord::ConnectionAdapters::ReferenceDefinition
        def initialize \
            name,
            polymorphic: false,
            index: true,
            foreign_key: false,
            type: :integer,
            **options
          @name = name
          @polymorphic = polymorphic
          @index = index
          @foreign_key = foreign_key
          @type = type
          @options = options

          if polymorphic && foreign_key
            raise ArgumentError, "Cannot add a foreign key to a polymorphic relation"
          end
        end

        private

        def columns
          result = [[column_name, type, options]]

          if polymorphic
            type_options = polymorphic_options.merge limit: 255
            result.unshift ["#{name}_type", :string, type_options]
          end
          result
        end
      end

      class IndexDefinition < ActiveRecord::ConnectionAdapters::IndexDefinition
        attr_reader :null_filtered, :interleve_in, :storing, :orders

        def initialize \
            table_name,
            name,
            columns,
            unique: false,
            null_filtered: false,
            interleve_in: nil,
            storing: nil,
            orders: nil
          @table = table_name
          @name = name
          @unique = unique
          @null_filtered = null_filtered
          @interleve_in = interleve_in
          @storing = Array(storing)
          @orders = (orders || {}).symbolize_keys

          columns = columns.split(/\W/) if columns.is_a? String
          @columns = Array(columns).map(&:to_s)
        end

        def columns_with_order
          columns.each_with_object({}) do |c, result|
            result[c] = orders[c.to_sym].to_s.upcase
          end
        end
      end
    end
  end
end
