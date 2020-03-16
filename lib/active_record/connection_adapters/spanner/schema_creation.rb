module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

        # rubocop:disable Naming/MethodName, Metrics/AbcSize

        def visit_TableDefinition o
          create_sql = +"CREATE TABLE #{quote_table_name o.name} "
          statements = o.columns.map { |c| accept c }

          o.foreign_keys.each do |to_table, options|
            statements << foreign_key_in_create(o.name, to_table, options)
          end

          create_sql << "(#{statements.join ', '}) " if statements.any?

          primary_keys = if o.primary_keys
                           o.primary_keys
                         else
                           pk_names = o.columns.each_with_object [] do |c, r|
                             r << c.name if c.type == :primary_key
                           end
                           PrimaryKeyDefinition.new pk_names
                         end
          create_sql << accept(primary_keys)

          if o.interleave_in
            create_sql << " , INTERLEAVE IN PARENT #{o.interleave_in}"
            create_sql << " ON DELETE #{o.on_delete}" if o.on_delete
          end

          create_sql
        end

        def visit_DropTableDefinition o
          "DROP TABLE #{quote_table_name o.name}"
        end

        def visit_ColumnDefinition o
          o.sql_type = type_to_sql o.type, o.options

          column_sql = +"#{quote_column_name o.name} #{o.sql_type}"
          add_column_options! column_sql, column_options(o)
          column_sql
        end

        def visit_DropColumnDefinition o
          "ALTER TABLE #{quote_table_name o.table_name} DROP" \
           " COLUMN #{quote_column_name o.name}"
        end

        def visit_ChangeColumnDefinition o
          sql = +"ALTER TABLE #{quote_table_name o.table_name} ALTER COLUMN "
          sql << accept(o.column)
          sql
        end

        def visit_DropIndexDefinition o
          "DROP INDEX #{quote_column_name o.name}"
        end

        def visit_IndexDefinition o
          sql = +"CREATE"
          sql << " UNIQUE" if o.unique
          sql << " NULL_FILTERED" if o.null_filtered
          sql << " INDEX #{quote_column_name o.name} "

          columns_sql = o.columns_with_order.map do |c, order|
            order_sql = +quote_column_name(c)
            order_sql << " DESC" if order == "DESC"
            order_sql
          end

          sql << "ON #{quote_table_name o.table_name} (#{columns_sql.join ', '})"

          if o.storing.any?
            storing = o.storing.map { |s| quote_column_name s }
            sql << " STORING (#{storing.join ', '})"
          end
          if o.interleve_in
            sql << ", INTERLEAVE IN #{quote_column_name o.interleve_in}"
          end
          sql
        end

        # rubocop:enable Naming/MethodName, Metrics/AbcSize

        def add_column_options! sql, options
          if options[:null] == false || options[:primary_key] == true
            sql << " NOT NULL"
          end

          if !options[:allow_commit_timestamp].nil? &&
             options[:column].sql_type == "TIMESTAMP"
            sql << " OPTIONS (allow_commit_timestamp = "\
                   "#{options[:allow_commit_timestamp]})"
          end

          sql
        end
      end
    end
  end
end
