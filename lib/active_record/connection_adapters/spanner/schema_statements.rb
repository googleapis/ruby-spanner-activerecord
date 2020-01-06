# frozen_string_literal: true

require "active_record/connection_adapters/spanner/schema_creation"
require "active_record/connection_adapters/spanner/schema_definitions"

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      #
      # # SchemaStatements
      #
      # Collection of methods to handle database schema.
      #
      # [Schema Doc](https://cloud.google.com/spanner/docs/information-schema)
      #
      module SchemaStatements
        def current_database
          @connection.database_id
        end

        def add_column table_name, column_name, type, **options
        end

        def remove_column table_name, column_name
        end

        def change_column table_name, column_name, type, options = {}
        end

        def change_column_null table_name, column_name, null, default = nil
        end

        def change_column_default *_args
          raise SpannerActiverecord::Error, \
                "change column default not supported"
        end

        def rename_column table_name, column_name, new_column_name
        end

        def column_definitions table_name
          execute(
            "SELECT * FROM information_schema.columns WHERE table_name=#{quote table_name}"
          ).to_a
        end

        def new_column_from_field _table_name, field
          Column.new \
            field[:COLUMN_NAME],
            field[:COLUMN_DEFAULT],
            fetch_type_metadata(field[:SPANNER_TYPE], field[:ORDINAL_POSITION]),
            field[:IS_NULLABLE] == "YES",
            nil
        end

        def indexes table_name
          execute(
            "SELECT * FROM information_schema.indexes WHERE table_name=#{quote table_name}"
          ).map do |index_data|
            column_sql = <<~SQL
              SELECT * FROM information_schema.index_columns
               WHERE table_name=#{quote table_name}
               AND index_name=#{quote index_data[:INDEX_NAME]}
            SQL
            index_colums_info = execute(column_sql).to_a
            columns = index_colums_info.map { |c| c[:COLUMN_NAME] }

            orders = index_colums_info.each_wth_object do |column, result|
              if column[:COLUMN_ORDERING] == "DESC"
                result[column[:COLUMN_NAME]] = :desc
              end
            end

            IndexDefinition.new(
              index_data[:TABLE_NAME],
              index_data[:INDEX_NAME],
              index_data[:IS_UNIQUE],
              columns,
              orders: orders
            )
          end
        end

        def add_index table_name, column_name, options = {}
          # CHECK: Use existing query generator
        end

        def remove_index _table_name, options = {}
          execute_ddl "DROP INDEX #{options[:name]}"
        end

        def fetch_type_metadata sql_type, ordinal_position = nil
          Spanner::TypeMetadata.new \
            super(sql_type), ordinal_position: ordinal_position
        end

        # Returns the relation names useable to back Active Record models.
        # For most adapters this means all #tables
        def data_sources
          execute(data_source_sql).map { |row| row[:table_name] }
        end
        alias tables data_sources

        def table_exists? table_name
          execute(data_source_sql(table_name)).any?
        end

        def create_table table_name, **options
          td = create_table_definition table_name, options

          if options[:id] != false
            pk = options.fetch :primary_key do
              Base.get_primary_key table_name.to_s.singularize
            end

            if pk.is_a? Array
              td.primary_keys pk
            else
              td.primary_key pk, options.fetch(:id, :primary_key), options.except(:comment)
            end
          end

          yield td if block_given?

          if options[:force]
            drop_table table_name, options.merge(if_exists: true)
          end

          execute_ddl schema_creation.accept td
        end

        def drop_table table_name, _options = {}
          execute_ddl "DROP TABLE #{table_name}"
        end

        # Foreign keys are not supported.
        def foreign_keys _table_name
          []
        end

        def schema_creation
          Spanner::SchemaCreation.new self
        end

        def create_table_definition *args
          Spanner::TableDefinition.new(self, *args)
        end

        def data_source_sql name = nil, type: nil
          scope = quoted_scope name, type: type

          sql = +"SELECT table_name FROM information_schema.tables"
          sql << " WHERE table_schema = #{scope[:schema]}"
          sql << " AND table_catalog = #{scope[:type]}"
          sql << " AND table_name = #{scope[:name]}" if scope[:name]
          sql
        end

        def quoted_scope name = nil, type: nil
          scope = {}
          scope[:schema] = quote ""
          scope[:type] = quote(type || "")
          scope[:name] = quote name if name
          scope
        end
      end
    end
  end
end
