require "active_record/connection_adapters/abstract/quoting"

module SpannerActiverecord
  class InformationSchema
    include ActiveRecord::ConnectionAdapters::Quoting

    def initalize connection
      @connection = connection
    end

    def tables schema_name: "", load_columns: false
      sql = "SELECT * FROM information_schema.tables" \
          " WHERE table_schema=%<schema_name>s"
      rows = execute_query sql, schema_name: schema_name

      return rows.map { |r| r["TABLE_NAME"] } unless load_columns

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

    # TODO: WIP
    def indexes table_name
      sql = "SELET * FROM information_schema.indexes " \
        "WHERE table_name=%<table_name>s"
      execute_query(sql, table_name: table_name).map do |index|
        columns = index_columns table_name, index["INDEX_NAME"]

        Index.new \
          table_name,
          index_data["INDEX_NAME"],
          index_data["IS_UNIQUE"],
          columns,
          orders: orders,
          null_filtered: index["IS_NULL_FILTERED"],
          storing: storing,
          interleve_in: index["PARENT_TABLE_NAME"]
      end
    end

    def index_columns table_name, index_name
      sql = "SELECT * FROM information_schema.index_columns" \
            " WHERE table_name=%<table_name>s" \
            " AND index_name=%<index_name>s"
      execute_query(
        sql,
        table_name: table_name, index_name: index_name
      ).map do |row|
        Index::Column.new \
          @connection,
          table_name,
          index_name,
          row["COLUMN_NAME"],
          order: row["COLUMN_ORDERING"],
          ordinal_position: row["ORDINAL_POSITION"]
      end
    end

    private

    def execute_query sql, params = {}
      params = params.transform_values { |v| quote v }
      sql = format sql, params
      @connection.execute_query sql
    end
  end
end
