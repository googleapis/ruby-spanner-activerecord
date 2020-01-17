module SpannerActiverecord
  class Table
    class Column
      attr_accessor :table_name, :name, :type, :limit, :ordinal_position,
                    :allow_commit_timestamp, :default, :primary_key
      attr_reader :reference_index
      attr_writer :nullable

      def initialize \
          table_name,
          name,
          type,
          limit: nil,
          ordinal_position: nil,
          nullable: true,
          allow_commit_timestamp: nil,
          default: nil,
          reference_index_name: nil,
          connection: nil
        @connection = connection
        @table_name = table_name.to_s
        @name = name.to_s
        @type = type
        @limit = limit
        @nullable = nullable != false
        @ordinal_position = ordinal_position
        @allow_commit_timestamp = allow_commit_timestamp
        @default = default
        @primary_key = false
        self.reference_index = reference_index_name if reference_index_name
      end

      def reference_index= index_name
        @reference_index = Index.new(
          table_name,
          index_name,
          Index::Column.new(
            table_name,
            index_name, name,
            connection: @connection
          ),
          connection: @connection
        )
      end

      def nullable
        return false if primary_key
        @nullable
      end

      def add
        @connection.execute_ddl add_sql
      end

      def add_sql
        statements = [
          "ALTER TABLE #{table_name} ADD #{new_column_sql :add_column}"
        ]

        statements << change_sql unless nullable
        statements
      end

      def drop
        statements = drop_indexes_sql
        statements << drop_sql
        @connection.execute_ddl statements
      end

      def drop_sql
        "ALTER TABLE #{table_name} DROP COLUMN #{name}"
      end

      def drop_indexes_sql
        information_schema = InformationSchema.new @connection
        information_schema.indexes_by_columns(table_name, name).map(&:drop_sql)
      end

      def change action = nil
        @connection.execute_ddl change_sql(action)
      end

      def change_sql action = nil
        sql = if action == :options
                set_options_sql
              else
                type_or_null_change_sql
              end

        "ALTER TABLE #{table_name} ALTER COLUMN #{name} #{sql}"
      end

      def set_options_sql
        option_value = allow_commit_timestamp ? "true" : "null"
        "SET OPTIONS (allow_commit_timestamp=#{option_value})"
      end

      def type_or_null_change_sql
        value = nullable ? "" : "NOT NULL"
        "#{spanner_type} #{value}"
      end

      def rename _new_name
        raise NotSupportedError, "rename of column not supported"
      end

      def spanner_type
        if type == "STRING" || type == "BYTES"
          return "#{type}(#{limit || 'MAX'})"
        end

        type
      end

      def new_column_sql action = nil
        sql = +"#{name} #{spanner_type}"

        # Column with NOT NULL is not supported while adding column.
        unless action == :add_column
          sql << " NOT NULL" unless nullable
        end

        # Supported only for TIMESTAMP type
        if allow_commit_timestamp
          sql << " OPTIONS (allow_commit_timestamp=true)"
        end

        sql
      end

      def self.parse_type_and_limit type
        matched = /^([A-Z]*)\((.*)\)/.match type
        return [type] unless matched

        limit = matched[2]
        limit = limit.to_i unless limit == "MAX"

        [matched[1], limit]
      end
    end
  end
end
