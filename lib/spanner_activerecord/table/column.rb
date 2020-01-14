module SpannerActiverecord
  class Table
    class Column
      attr_reader :table_name, :name, :type, :limit, :ordinal_position,
                  :allow_commit_timestamp, :reference_index, :default
      attr_accessor :nullable

      def initialize \
          table_name,
          name,
          type,
          limit: nil,
          ordinal_position: nil,
          nullable: nil,
          allow_commit_timestamp: nil,
          default: nil,
          reference_index_name: nil,
          connection: nil
        @connection = connection
        @table_name = table_name.to_s
        @name = name.to_s
        @type = type
        @limit = limit
        @nullable = nullable.nil? || nullable == false
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

      def primary_key!
        @primary_key = true
        @nullable = false
      end

      def primary_key?
        @primary_key
      end

      def add
        @connection.execute_ddl add_sql
      end

      def add_sql
        "ALTER TABLE #{table_name} ADD #{new_column_sql}"
      end

      def drop
        @connection.execute_ddl drop_sql
      end

      def drop_sql
        "ALTER TABLE #{table_name} DROP COLUMN #{name}"
      end

      def change action
        sql = if action == :options
                set_options_sql
              elsif [:nullable, :type].include? action
                type_or_null_change_sql
              end

        @connection.execute_ddl sql if sql
      end

      def set_options_sql
        option_value = allow_commit_timestamp ? "true" : "null"
        "ALTER TABLE #{table_name} ALTER COLUMN #{name}" \
           " SET OPTIONS (allow_commit_timestamp=#{option_value})"
      end

      def type_or_null_change_sql
        value = nullable ? "": "NOT NULL"
        "ALTER TABLE #{table_name} ALTER COLUMN #{name} #{spanner_type} #{value}"
      end

      def rename _new_name
        raise NotSupportedError, "rename of column not supported"
      end

      def spanner_type
        return "#{type}(#{limit})" if limit
        return "#{type}(MAX)" if type == "STRING" || type == "BYTES"
        type
      end

      def new_column_sql
        sql = +"#{name} #{spanner_type}"
        sql << " NOT NULL" unless nullable

        if allow_commit_timestamp
          sql << " OPTIONS (allow_commit_timestamp=true)"
        end

        sql
      end
    end
  end
end
