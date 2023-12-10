# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module ConnectionAdapters #:nodoc:
    module Spanner
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        attr_reader :interleave_in_parent

        def interleave_in parent, on_delete = nil
          @interleave_in_parent = parent
          @on_delete = on_delete
        end

        def parent_key name, type: nil
          column name, :parent_key, null: false, passed_type: type
        end

        def interleave_in?
          @interleave_in_parent != nil
        end

        def on_delete
          "CASCADE" if @on_delete == :cascade
        end

        def references *args, **options
          args.each do |ref_name|
            Spanner::ReferenceDefinition.new(ref_name, **options).add_to(self)
          end
        end
        alias belongs_to references

        def new_column_definition name, type, **options
          case type
          when :virtual
            type = options[:type]
          end

          super
        end

        def valid_column_definition_options
          super + [:type, :array, :allow_commit_timestamp, :as, :stored, :parent_key, :passed_type, :index]
        end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        def primary_key name, type = :primary_key, **options
          type = :string # rubocop:disable Lint/ShadowedArgument
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
          @foreign_key = foreign_key
          # Only add an index if there is no foreign key, as Cloud Spanner will automatically add a managed index when
          # a foreign key is added.
          @index = index unless foreign_key
          @type = type
          @options = options

          return unless polymorphic && foreign_key
          raise ArgumentError, "Cannot add a foreign key to a polymorphic relation"
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
        attr_reader :null_filtered, :interleave_in, :storing, :orders

        def initialize \
            table_name,
            name,
            columns,
            unique: false,
            null_filtered: false,
            interleave_in: nil,
            storing: nil,
            orders: nil
          @table = table_name
          @name = name
          @unique = unique
          @null_filtered = null_filtered
          @interleave_in = interleave_in
          @storing = Array(storing)
          columns = columns.split(/\W/) if columns.is_a? String
          @columns = Array(columns).map(&:to_s)
          @orders = orders || {}

          unless @orders.is_a? Hash
            @orders = columns.each_with_object({}) { |c, r| r[c] = orders }
          end

          @orders = @orders.symbolize_keys
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
