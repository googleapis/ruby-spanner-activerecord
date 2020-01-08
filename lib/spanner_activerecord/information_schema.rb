require "active_record/connection_adapters/quoting"

module SpannerActiverecord
  class InformationSchema
    include ActiveRecord::ConnectionAdapters::Quoting

    SQL_STATEMENTS = {
      indexes: "SELET * FROM information_schema.indexes WHERE table_name=%{table_name}",
      index_columns: <<~SQL
        SELECT * FROM information_schema.index_columns
          WHERE table_name=%{table_name}
          AND index_name=%{index_name}
      SQL
    }.freeze

    def initalize client
      @client = client
    end

    def indexes table_name
      execute(:indexes, table_name: table_name).map do |index|
        columns = index_columns table_name, index[:INDEX_NAME]
        columns.to_a

        Index.new \
          table_name,
          index_data[:INDEX_NAME],
          index_data[:IS_UNIQUE],
          columns,
          orders: orders,
          null_filtered: index[:IS_NULL_FILTERED],
          storing: storing,
          interleve_in: index[:PARENT_TABLE_NAME]
      end
    end

    def index_columns table_name, index_name
      execute(
        :index_columns,
        table_name: table_name, index_name: index_name
      ).rows.to_a
    end

    private


    def execute statement_name, params = {}
      sql = format SQL_STATEMENTS[statement_name], params
      @client.execute_query(sql).rows
    end
  end
end
