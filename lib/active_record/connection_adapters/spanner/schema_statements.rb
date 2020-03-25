# frozen_string_literal: true

require "active_record/connection_adapters/spanner/schema_creation"

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
              td.primary_key pk, options.fetch(:id, :primary_key), {}
            end
          end

          yield td if block_given?

          statements = []

          if options[:force]
            statements.concat drop_table_with_indexes_sql(table_name, options)
          end

          statements << schema_creation.accept(td)

          td.indexes.each do |column_name, index_options|
            id = create_index_definition table_name, column_name, index_options
            statements << schema_creation.accept(id)
          end

          execute_ddl statements
        end

        def drop_table table_name, options = {}
          execute_ddl drop_table_with_indexes_sql(table_name, options)
        end

        def create_join_table table_1, table_2, column_options: {}, **options
          return super unless block_given?

          super do |td|
            yield td
            td.primary_key :id unless td.columns.any?(&:primary_key?)
          end
        end

        def rename_table _table_name, _new_name
          raise SpannerActiverecord::NotSupportedError, \
                "rename_table is not implemented"
        end

        # Column

        def column_definitions table_name
          information_schema.table_columns table_name
        end

        def new_column_from_field _table_name, field
          ConnectionAdapters::Column.new \
            field.name,
            field.default,
            fetch_type_metadata(field.spanner_type, field.ordinal_position),
            field.nullable
        end

        def fetch_type_metadata sql_type, ordinal_position = nil
          Spanner::TypeMetadata.new \
            super(sql_type), ordinal_position: ordinal_position
        end

        def add_column table_name, column_name, type, **options
          at = create_alter_table table_name
          at.add_column column_name, type, options
          execute_ddl schema_creation.accept(at)
        end

        def remove_column table_name, column_name
          execute_ddl drop_column_sql(table_name, column_name)
        end

        def remove_columns table_name, *column_names
          if column_names.empty?
            raise ArgumentError, "You must specify at least one column name. "\
              "Example: remove_columns(:people, :first_name)"
          end

          statements = []

          column_names.each do |column_name|
            statements.concat drop_column_sql(table_name, column_name)
          end

          execute_ddl statements
        end

        def change_column table_name, column_name, type, options = {}
          column = information_schema.table_column table_name, column_name

          unless column
            raise ArgumentError,
                  "Column '#{column_name}' not exist for table '#{table_name}'"
          end

          column = new_column_from_field table_name, column

          type ||= column.type
          options[:null] = column.null unless options.key? :null

          if ["STRING", "BYTES"].include? type
            options[:limit] = column.limit unless options.key? :limit
          end

          # Only timestamp type can set commit timestamp
          if type == "TIMESTAMP" &&
             options.key?(:allow_commit_timestamp) == false
            options[:allow_commit_timestamp] = column.allow_commit_timestamp
          end

          td = create_table_definition table_name
          cd = td.new_column_definition column.name, type, options

          ccd = Spanner::ChangeColumnDefinition.new table_name, cd, column.name
          execute_ddl schema_creation.accept(ccd)
        end

        def change_column_null table_name, column_name, null, _default = nil
          change_column table_name, column_name, nil, null: null
        end

        def change_column_default _table_name, _column_name, _default_or_changes
          raise SpannerActiverecord::NotSupportedError, \
                "change column with default value not supported."
        end

        def rename_column _table_name, _column_name, _new_column_name
          raise SpannerActiverecord::NotSupportedError, \
                "rename column not supported."
        end

        # Index

        def indexes table_name
          information_schema.indexes(
            table_name, index_type: "INDEX"
          ).map do |index|
            IndexDefinition.new(
              index.table,
              index.name,
              index.columns.map(&:name),
              unique: index.unique,
              null_filtered: index.null_filtered,
              interleve_in: index.interleve_in,
              storing: index.storing,
              orders: index.orders
            )
          end
        end

        def index_name_exists? table_name, index_name
          !information_schema.index(table_name, index_name).nil?
        end

        def add_index table_name, column_name, options = {}
          id = create_index_definition table_name, column_name, options
          execute_ddl schema_creation.accept(id)
        end

        def remove_index table_name, options = {}
          index_name = index_name_for_remove table_name, options
          sql = schema_creation.accept(
            DropIndexDefinition.new(index_name)
          )
          execute_ddl sql
        end

        def rename_index table_name, old_name, new_name
          validate_index_length! table_name, new_name

          old_index = information_schema.index table_name, old_name
          return unless old_index

          statements = [
            schema_creation.accept(DropIndexDefinition.new(old_name))
          ]

          id = IndexDefinition.new \
            old_index.table,
            new_name,
            old_index.columns.map(&:name),
            unique: old_index.unique,
            null_filtered: old_index.null_filtered,
            interleve_in: old_index.interleve_in,
            storing: old_index.storing,
            orders: old_index.orders

          statements << schema_creation.accept(id)
          execute_ddl statements
        end

        # Primary Keys

        def primary_keys table_name
          index_columns = information_schema.table_primary_keys table_name
          index_columns.map(&:name)
        end

        # Foreign Keys

        def foreign_keys table_name
          raise ArgumentError if table_name.blank?

          information_schema.foreign_keys(table_name).map do |fk|
            options = {
              column: fk.columns.first,
              name: fk.name,
              primary_key: fk.ref_columns.first,
              on_delete: fk.on_update,
              on_update: fk.on_update
            }

            ForeignKeyDefinition.new table_name, fk.ref_table, options
          end
        end

        def add_foreign_key from_table, to_table, options = {}
          options = foreign_key_options from_table, to_table, options
          at = create_alter_table from_table
          at.add_foreign_key to_table, options

          execute_ddl schema_creation.accept(at)
        end

        def remove_foreign_key from_table, to_table = nil, **options
          fk_name_to_delete = foreign_key_for!(
            from_table, to_table: to_table, **options
          ).name

          at = create_alter_table from_table
          at.drop_foreign_key fk_name_to_delete

          execute_ddl schema_creation.accept(at)
        end

        # Reference Column

        def add_reference table_name, ref_name, **options
          ReferenceDefinition.new(ref_name, options).add_to(
            update_table_definition(table_name, self)
          )
        end
        alias add_belongs_to add_reference

        def type_to_sql type, limit: nil, precision: nil, scale: nil, **options
          type = type.to_sym if type
          native_type = native_database_types[type]

          case type
          when :primary_key
            native_type
          when :string, :text, :binary
            "#{native_type[:name]}(#{limit || native_type[:limit]})"
          when :integer, :decimal, :float
            if limit
              raise ArgumentError,
                    "No #{native_type[:name]} type is not supporting limit"
            end
            native_type[:name]
          else
            super
          end
        end

        def quoted_scope name = nil, type: nil
          scope = { schema: quote("") }
          scope[:name] = quote name if name
          scope[:type] = quote type if type
          scope
        end

        private

        def schema_creation
          SchemaCreation.new self
        end

        def create_table_definition *args
          TableDefinition.new self, *args
        end

        def create_index_definition table_name, column_name, **options
          column_names = index_column_names column_name

          options.assert_valid_keys :unique, :order, :name, :interleve_in,
                                    :storing, :null_filtered

          index_name = options[:name].to_s if options.key? :name
          index_name ||= index_name table_name, column_names

          validate_index_length! table_name, index_name

          if data_source_exists?(table_name) &&
             index_name_exists?(table_name, index_name)
            raise ArgumentError, "Index name '#{index_name}' on table" \
                                 "'#{table_name}' already exists"
          end

          IndexDefinition.new \
            table_name,
            index_name,
            column_names,
            unique: options[:unique],
            null_filtered: options[:null_filtered],
            interleve_in: options[:interleve_in],
            storing: options[:storing],
            orders: options[:order]
        end

        def drop_table_with_indexes_sql table_name, options
          statements = []

          table = information_schema.table table_name, view: :indexes
          return statements unless table

          table.indexes.each do |index|
            next if index.primary?

            statements << schema_creation.accept(
              DropIndexDefinition.new(index.name)
            )
          end

          statements << schema_creation.accept(
            DropTableDefinition.new(table_name, options)
          )
          statements
        end

        def drop_column_sql table_name, column_name
          statements = information_schema.indexes_by_columns(
            table_name, column_name
          ).map do |index|
            schema_creation.accept DropIndexDefinition.new(index.name)
          end

          foreign_keys(table_name).each do |fk|
            next unless fk.column.to_s == column_name.to_s

            at = create_alter_table table_name
            at.drop_foreign_key fk.name
            statements << schema_creation.accept(at)
          end

          statements << schema_creation.accept(
            DropColumnDefinition.new(table_name, column_name)
          )

          statements
        end
      end
    end
  end
end
