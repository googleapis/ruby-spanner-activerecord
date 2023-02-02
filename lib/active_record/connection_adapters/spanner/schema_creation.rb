# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaCreation < SchemaCreation
        private

        # rubocop:disable Naming/MethodName, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength

        def visit_TableDefinition o
          create_sql = +"CREATE TABLE #{quote_table_name o.name} "
          statements = o.columns.map { |c| accept c }

          if ActiveRecord::VERSION::MAJOR >= 7
            o.foreign_keys.each do |fk|
              statements << accept(fk)
            end
          else
            o.foreign_keys.each do |to_table, options|
              statements << foreign_key_in_create(o.name, to_table, options)
            end
          end

          if ActiveRecord::VERSION::MAJOR >= 7
            statements.concat(o.check_constraints.map { |chk| accept chk })
          elsif ActiveRecord::VERSION::MAJOR == 6 && ActiveRecord::VERSION::MINOR >= 1
            statements.concat(
              o.check_constraints.map { |expression, options| check_constraint_in_create o.name, expression, options }
            )
          end

          create_sql << "(#{statements.join ', '}) " if statements.any?

          primary_keys = if o.primary_keys
                           o.primary_keys
                         else
                           pk_names = o.columns.each_with_object [] do |c, r|
                             if c.type == :primary_key || c.primary_key?
                               r << c.name
                             end
                           end
                           PrimaryKeyDefinition.new pk_names
                         end

          if o.interleave_in?
            parent_names = o.columns.each_with_object [] do |c, r|
              if c.type == :parent_key
                r << c.name
              end
            end
            primary_keys.name = parent_names.concat primary_keys.name
            create_sql << accept(primary_keys)
            create_sql << ", INTERLEAVE IN PARENT #{quote_table_name o.interleave_in_parent}"
            create_sql << " ON DELETE #{o.on_delete}" if o.on_delete
          else
            create_sql << accept(primary_keys)
          end

          create_sql
        end

        def visit_DropTableDefinition o
          "DROP TABLE #{quote_table_name o.name}"
        end

        def visit_ColumnDefinition o
          o.sql_type = type_to_sql o.type, **o.options
          column_sql = +"#{quote_column_name o.name} #{o.sql_type}"
          add_column_options! o, column_sql, column_options(o)
          column_sql
        end

        def visit_AddColumnDefinition o
          # Overridden to add the optional COLUMN keyword. The keyword is only optional
          # on real Cloud Spanner, the emulator requires the COLUMN keyword to be included.
          +"ADD COLUMN #{accept o.column}"
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
          "DROP INDEX #{quote_table_name o.name}"
        end

        def visit_IndexDefinition o
          sql = +"CREATE"
          sql << " UNIQUE" if o.unique
          sql << " NULL_FILTERED" if o.null_filtered
          sql << " INDEX #{quote_table_name o.name} "

          columns_sql = o.columns_with_order.map do |c, order|
            order_sql = +quote_column_name(c)
            order_sql << " DESC" if order == "DESC"
            order_sql
          end

          sql << "ON #{quote_table_name o.table} (#{columns_sql.join ', '})"

          if o.storing.any?
            storing = o.storing.map { |s| quote_column_name s }
            sql << " STORING (#{storing.join ', '})"
          end
          if o.interleave_in
            sql << ", INTERLEAVE IN #{quote_table_name o.interleave_in}"
          end
          sql
        end

        # rubocop:enable Naming/MethodName, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength

        def add_column_options! column, sql, options
          if options[:null] == false || options[:primary_key] == true
            sql << " NOT NULL"
          end
          if options.key? :default
            sql << " DEFAULT (#{quote_default_expression options[:default], column})"
          end

          if !options[:allow_commit_timestamp].nil? &&
             options[:column].sql_type == "TIMESTAMP"
            sql << " OPTIONS (allow_commit_timestamp = "\
                   "#{options[:allow_commit_timestamp]})"
          end

          if (as = options[:as])
            sql << " AS (#{as})"

            sql << " STORED" if options[:stored]
            unless options[:stored]
              raise ArgumentError, "" \
                "Cloud Spanner currently does not support generated columns without the STORED option." \
                "Specify 'stored: true' option for `#{options[:column].name}`"
            end
          end

          sql
        end
      end
    end
  end
end
