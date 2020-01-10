require "active_record/connection_adapters/abstract/quoting"

module SpannerActiverecord
  class InformationSchema
    include ActiveRecord::ConnectionAdapters::Quoting

    def initialize connection
      @connection = connection
    end

    def tables schema_name: ""
      sql = "SELECT * FROM information_schema.tables" \
          " WHERE table_schema=%<schema_name>s"
      rows = execute_query sql, schema_name: schema_name

      rows.map do |row|
        Table.new \
          @connection,
          row["TABLE_NAME"],
          parent_table: row["PARENT_TABLE_NAME"],
          on_delete: row["ON_DELETE_ACTION"],
          schema_name: row["TABLE_SCHEMA"],
          catalog: row["TABLE_CATALOG"]
      end
    end

    def table_columns table_name
      sql = "SELECT * FROM information_schema.columns" \
          " WHERE table_name=%<table_name>s"

      execute_query(sql, table_name: table_name).map do |row|
        Table::Column.new \
          @connection,
          table_name,
          row["COLUMN_NAME"],
          row["SPANNER_TYPE"],
          ordinal_position: row["ORDINAL_POSITION"],
          nullable: row["IS_NULLABLE"]
      end
    end

    def indexes table_name
      table_indexes_columns = index_columns table_name

      sql = "SELECT * FROM information_schema.indexes" \
        " WHERE table_name=%<table_name>s"
      execute_query(sql, table_name: table_name).map do |row|
        columns = table_indexes_columns.select do |c|
          c.index_name == row["INDEX_NAME"]
        end

        Index.new \
          @connection,
          table_name,
          row["INDEX_NAME"],
          columns,
          type: row["INDEX_TYPE"],
          unique: row["IS_UNIQUE"],
          null_filtered: row["IS_NULL_FILTERED"],
          interleve_in: row["PARENT_TABLE_NAME"],
          state: row["INDEX_STATE"]
      end
    end

    def index_columns table_name, index_name: nil
      sql = +"SELECT * FROM information_schema.index_columns" \
            " WHERE table_name=%<table_name>s"
      sql << " AND index_name=%<index_name>s" if index_name

      execute_query(
        sql,
        table_name: table_name, index_name: index_name
      ).map do |row|
        Index::Column.new \
          @connection,
          table_name,
          row["INDEX_NAME"],
          row["COLUMN_NAME"],
          order: row["COLUMN_ORDERING"],
          ordinal_position: row["ORDINAL_POSITION"]
      end
    end

    private

    def index_column_orders columns
    end

    def execute_query sql, params = {}
      params = params.transform_values { |v| quote v }
      sql = format sql, params
      @connection.execute_query sql
    end
  end
end
