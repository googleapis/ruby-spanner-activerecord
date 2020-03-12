module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaCreation
        def initialize adapter, connection
          @adapter = adapter
          @connection = connection
        end

        def create_table obj
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

          obj.indexes.each do |index_columns, options|
            add_index table, index_columns, options
          end

          obj.foreign_keys.each do |to_table, options|
            add_foreign_key table, to_table, options
          end

          table
        end

        def alter_table obj
          table = SpannerActiverecord::Table.new(
            obj.name, connection: @connection
          )
          add_columns table, obj.adds.map(&:column)
          table
        end

        private

        def add_columns table, column_definations
          column_definations.each do |cd|
            column = table.add_column \
              cd.name,
              @adapter.type_to_sql(cd.type),
              limit: cd.limit,
              nullable: cd.null,
              allow_commit_timestamp: cd.options[:allow_commit_timestamp]
            column.primary_key = true if cd.primary_key?
          end
        end

        def add_index table, column_names, options
          index_name = options[:name].to_s if options.key? :name
          index_name ||= @adapter.index_name table.name, column_names

          options[:orders] ||= {}
          columns = Array(column_names).each_with_object({}) do |c, r|
            r[c.to_sym] = options[c.to_sym]
          end

          table.add_index(
            index_name,
            columns,
            unique: options[:unique],
            null_filtered: options[:null_filtered],
            interleve_in: options[:interleve_in],
            storing: options[:storing]
          )
        end

        def add_foreign_key from_table, to_table, options
          prefix = ActiveRecord::Base.table_name_prefix
          suffix = ActiveRecord::Base.table_name_suffix
          to_table = "#{prefix}#{to_table}#{suffix}"
          options = @adapter.foreign_key_options(
            from_table.name, to_table, options
          )
          fk_def = ForeignKeyDefinition.new from_table, to_table, options

          from_table.add_foreign_key(
            fk_def.name,
            fk_def.column,
            fk_def.to_table,
            fk_def.primary_key
          )
        end
      end
    end
  end
end
