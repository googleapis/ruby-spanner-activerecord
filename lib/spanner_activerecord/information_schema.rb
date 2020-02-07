require "active_record/connection_adapters/abstract/quoting"

module SpannerActiverecord
  class InformationSchema
    include ActiveRecord::ConnectionAdapters::Quoting

    attr_reader :connection

    def initialize connection
      @connection = connection
    end

    def tables table_name: nil, schema_name: nil, view: nil
      sql = +"SELECT * FROM information_schema.tables" \
          " WHERE table_schema=%<schema_name>s"
      sql << " AND table_name=%<table_name>s" if table_name

      rows = execute_query(
        sql,
        schema_name: (schema_name || ""), table_name: table_name
      )

      rows.map do |row|
        table = Table.new(
          row["TABLE_NAME"],
          parent_table: row["PARENT_TABLE_NAME"],
          on_delete: row["ON_DELETE_ACTION"],
          schema_name: row["TABLE_SCHEMA"],
          catalog: row["TABLE_CATALOG"],
          connection: @connection
        )
        if [:full, :columns].include? view
          table.columns = table_columns table.name
        end
        if [:full, :indexes].include? view
          table.indexes = indexes table.name
        end
        table
      end
    end

    def table table_name, schema_name: nil, view: nil
      tables(
        table_name: table_name,
        schema_name: schema_name,
        view: view
      ).first
    end

    def table_columns table_name, column_name: nil
      sql = +"SELECT * FROM information_schema.columns" \
          " WHERE table_name=%<table_name>s"

      if column_name
        sql << " AND column_name=%<column_name>s"
      end

      execute_query(
        sql,
        table_name: table_name,
        column_name: column_name
      ).map do |row|
        type, limit = Table::Column.parse_type_and_limit row["SPANNER_TYPE"]
        Table::Column.new \
          table_name,
          row["COLUMN_NAME"],
          type,
          limit: limit,
          ordinal_position: row["ORDINAL_POSITION"],
          nullable: row["IS_NULLABLE"] == "YES",
          default: row["COLUMN_DEFAULT"],
          connection: @connection
      end
    end

    def table_column table_name, column_name
      table_columns(table_name, column_name: column_name).first
    end

    def table_primary_keys table_name
      index = indexes(table_name, index_type: "PRIMARY_KEY").first
      index&.columns || []
    end

    def indexes table_name, index_name: nil, index_type: nil
      table_indexes_columns = index_columns(
        table_name,
        index_name: index_name
      )

      sql = +"SELECT * FROM information_schema.indexes" \
        " WHERE table_name=%<table_name>s"
      sql << " AND index_name=%<index_name>s" if index_name
      sql << " AND index_type=%<index_type>s" if index_type

      execute_query(
        sql,
        table_name: table_name,
        index_name: index_name,
        index_type: index_type
      ).map do |row|
        columns = []
        storing = []
        table_indexes_columns.each do |c|
          next unless c.index_name == row["INDEX_NAME"]
          if c.ordinal_position
            columns << c
          else
            storing << c.name
          end
        end

        Index.new \
          table_name,
          row["INDEX_NAME"],
          columns,
          type: row["INDEX_TYPE"],
          unique: row["IS_UNIQUE"],
          null_filtered: row["IS_NULL_FILTERED"],
          interleve_in: row["PARENT_TABLE_NAME"],
          storing: storing,
          state: row["INDEX_STATE"],
          connection: @connection
      end
    end

    def index table_name, index_name
      indexes(table_name, index_name: index_name).first
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
          table_name,
          row["INDEX_NAME"],
          row["COLUMN_NAME"],
          order: row["COLUMN_ORDERING"],
          ordinal_position: row["ORDINAL_POSITION"],
          connection: @connection
      end
    end

    def indexes_by_columns table_name, column_names
      column_names = Array(column_names).map(&:to_s)

      indexes(table_name).select do |index|
        index.columns.any? { |c| column_names.include? c.name }
      end
    end

    private

    def execute_query sql, params = {}
      params = params.transform_values { |v| quote v }
      sql = format sql, params
      @connection.execute_query(sql).rows
    end
  end
end
