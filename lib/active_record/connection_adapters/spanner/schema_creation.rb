module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

        # rubocop:disable Naming/MethodName
        def visit_TableDefinition o
          create_sql = +"CREATE TABLE #{quote_table_name o.name}"

          statements = o.columns.map { |c| accept c }
          create_sql << "(#{statements.join ', '}) " if statements.present?

          # TODO: INTERLEAVE IN PARENT
          # i.e INTERLEAVE IN PARENT Albums ON DELETE CASCADE;
          # add_table_options!(create_sql, table_options(o))
          if o.primary_keys
            create_sql << accept(o.primary_keys)
          else
            column = o.columns.find(&:primary_key?)
            create_sql << "PRIMARY KEY (#{column.name})" if column
          end
          create_sql
        end
        # rubocop:enable Naming/MethodName

        def add_column_options! sql, options
          sql << " NOT NULL" if options[:null] == false

          if options[:allow_commit_timestamp] == true
            sql << " OPTIONS (allow_commit_timestamp=true)"
          end

          sql
        end
      end
    end
  end
end
