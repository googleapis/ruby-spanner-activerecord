# frozen_string_literal: true

require "active_record/connection_adapters/spanner/schema_creation"
#require "active_record/connection_adapters/spanner/schema_definitions"
# require "active_record/connection_adapters/spanner/column"

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

        # Table

        def data_sources
          information_schema.tables.map(&:name)
        end
        alias tables data_sources

        def table_exists? table_name
          !information_schema.table(table_name).nil?
        end
        alias data_source_exists? table_exists?

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

          table = information_schema.from_defination td
          table.create drop_table: options[:force]
          execute_ddl schema_creation.accept td
        end

        def drop_table table_name, _options = {}
          statements = information_schema.table(table_name)&.drop_table_sql
          execute_ddl statements if statements
        end

        # Column
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
          information_schema.table_columns table_name
        end

        def new_column_from_field _table_name, info_schema_column
          type_metdata = fetch_type_metadata \
            index_column_names.type, index_column_names.ordinal_position

          Spanner::Column.new \
            info_schema_column.name,
            index_column_names.default,
            type_metdata,
            info_schema_column.nullable?
        end

        def fetch_type_metadata sql_type, ordinal_position = nil
          Spanner::TypeMetadata.new \
            super(sql_type), ordinal_position: ordinal_position
        end

        # Index

        def indexes table_name
          information_schema.indexes table_name
        end

        def add_index table_name, column_name, options = {}
          index_name, index_type, index_columns, index_options = \
            add_index_options table_name, column_name, options

          sql = +"CREATE #{index_type} INDEX #{index_name}"
          sql << "ON #{table_name} (#{index_columns})"
          sql << ", #{index_options}" unless index_options.empty?

          execute_ddl sql
        end

        # TODO: Change - information_schema
        def add_index_options table_name, column_name, **options
          options.assert_valid_keys \
            :name, :unique, :null_filtered, :order, :interleve_in, :storing

          column_names = index_column_names column_name
          index_name = options[:name].to_s if options.key? :name
          index_name ||= index_name table_name, column_names

          index_type = options[:type].to_s if options.key? :type
          index_type ||= [
            (options[:unique] ? "UNIQUE" : ""),
            (options[:null_filtered] ? "NULL_FILTERED" : "")
          ].join " "

          options[:order]&.each do |column, order|
            next unless order == :desc
            column_index = column_names.index column.to_s
            next unless column_index
            column_names[column_index] = "#{column_names[column_index]} DESC"
          end

          index_options = []
          if options[:storing]
            index_options << "STORING (#{Array(options[:storing]).join ', ' })"
          end

          if options[:interleve_in]
            index_options << "INTERLEAVE IN #{options[:interleve_in]}"
          end

          if data_source_exists?(table_name) && index_name_exists?(table_name, index_name)
            raise ArgumentError, \
                  "Index name '#{name}' on table '#{table_name}' already exists"
          end

          [
            index_name,
            index_type,
            column_names.join(", "),
            index_options.join(", ")
          ]
        end

        def remove_index table_name, options = {}
          information_schema.index(table_name, options[:name])&.drop
        end

        # TODO: Change - information_schema
        def rename_index table_name, old_name, new_name
          validate_index_length table_name, new_name

          old_index_def = indexes(table_name).find { |i| i.name == old_name }
          return unless old_index_def

          add_index \
            table_name,
            old_index_def.columns,
            name: new_name,
            unique: old_index_def.unique,
            orders: old_index_def.orders,
            null_filtered: old_index_def.null_filtered,
            storing: old_index_def.storing,
            interleve_in: old_index_def.interleve_in
        end

        # Table

        def data_sources
          information_schema.tables.map(&:name)
        end
        alias tables data_sources

        def table_exists? table_name
          !information_schema.table(table_name).nil?
        end
        alias data_source_exists? table_exists?

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

          table = information_schema.new_table td, drop_table: options[:force]


          execute_ddl schema_creation.accept td
        end

        def drop_table table_name, _options = {}
          statements = information_schema.table(table_name)&.drop_table_sql
          execute_ddl statements if statements
        end

        # Foreign keys are not supported.
        def foreign_keys _table_name
          []
        end

        def schema_creation
          Spanner::SchemaCreation.new self
        end

        def create_table_definition *args
          Spanner::TableDefinition.new self, *args
        end
      end
    end
  end
end
