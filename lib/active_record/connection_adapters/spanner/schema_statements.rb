# frozen_string_literal: true

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

        def indexes table_name
          execute(
            "SELECT * FROM information_schema.indexes WHERE table_name=#{quote table_name}"
          ).each do |index_data|
            # TODO: Fetch index data from INFORMATION_SCHEMA.INDEX_COLUMNS
            # IndexDefinition.new {}
          end
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

        def add_index table_name, column_name, options = {}
          # CHECK: Use existing query generator
        end

        # Foreign keys are not supported.
        def foreign_keys _
          []
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

        # Returns the relation names useable to back Active Record models.
        # For most adapters this means all #tables
        def data_sources
          execute(data_source_sql).map { |row| row[:table_name] }
        end

        def column_definitions table_name
          execute(
            "SELECT * FROM information_schema.columns WHERE table_name=#{quote table_name}"
          ).to_a
        end

        def new_column_from_field _, field
          Column.new \
            field[:COLUMN_NAME],
            field[:COLUMN_DEFAULT],
            fetch_type_metadata(field[:SPANNER_TYPE], field[:ORDINAL_POSITION]),
            field[:IS_NULLABLE] == "YES",
            nil
        end

        def fetch_type_metadata sql_type, ordinal_position = nil
          Spanner::TypeMetadata.new \
            super(sql_type), ordinal_position: ordinal_position
        end
      end
    end
  end
end
