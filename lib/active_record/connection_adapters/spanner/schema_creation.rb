module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaCreation
        def initialize connection
          @connection = connection
        end

        def accept obj
          case obj
          when TableDefinition
            visit_table_definition obj
          when AlterTable
            visit_alter_table obj
          end
        end

        private

        def visit_table_definition obj
          table = SpannerActiverecord::Table.new(
            obj.name,
            parent_table: obj.options[:parent_table],
            on_delete: obj.options[:on_delete],
            connection: @connection
          )
          add_columns table, obj.columns

          table.primary_keys = if obj.primary_keys
                                 obj.primary_keys.map(&:name)
                               else
                                 obj.columns.select(&:primary_key?).map(&:name)
                               end

          statements = table.create_sql
          statements.concat table.indexes_sql
          statements.concat table.reference_indexes_sql
          statements
        end

        def visit_alter_table obj
          table = SpannerActiverecord::Table.new obj.name, connection: @connection
          add_columns table, obj.adds
          table.columns.map(&:add_sql)
        end

        def add_columns table, column_definations
          column_definations.each do |cd|
            column = table.add_column \
              cd.name,
              @connection.type_to_sql(cd.type),
              limit: cd.limit,
              nullable: cd.null,
              allow_commit_timestamp: cd.options[:allow_commit_timestamp]
            column.primary_key! if cd.primary_key?
          end
        end

        def visit_create_index
        end
      end
    end
  end
end
