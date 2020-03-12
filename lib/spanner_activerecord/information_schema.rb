require "active_record/connection_adapters/abstract/quoting"

module SpannerActiverecord
  class InformationSchema
    include ActiveRecord::ConnectionAdapters::Quoting

    attr_reader :connection

    def initialize connection
      @connection = connection
      @mutex = Mutex.new
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
      sql = +"SELECT * FROM information_schema.columns"
      sql << " WHERE table_name=%<table_name>s" if table_name
      sql << " AND column_name=%<column_name>s" if column_name

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
      sql << " AND spanner_is_managed=false"

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

    def foreign_keys table_name

      # table_name = orders
      # #<ActiveRecord::Result:0x00007ff7f916de08
      # @columns=["to_table", "primary_key", "column", "name", "on_update",
      # "on_delete"],
      # @rows=[["customers", "id", "customers_id", "fk_rails_a4cda5ee73",
      #  "NO ACTION", "NO ACTION"]], @hash_rows=nil, @column_types={}>

      # constraint_names
      # SELECT constraint_name from INFORMATION_SCHEMA.TABLE_CONSTRAINTS where
      # CONSTRAINT_TYPE='FOREIGN KEY' AND table_name='orders'

      # SELECT * from INFORMATION_SCHEMA.referential_constraints
      # Returns : constraint_name, update_rule, delete rule

      # SELECT * from INFORMATION_SCHEMA.key_column_usage
      # Returns: constraint_name, table_name(orders), column_name(customer_id)

      # SELECT * from INFORMATION_SCHEMA.constraint_column_usage
      # Returns: constraint_name, to_table_name(customers). column_name(id) primary_key

      sql = <<~SQL
        SELECT cc.table_name AS to_table,
               cc.column_name AS primary_key,
               fk.column_name as column,
               fk.constraint_name AS name,
               rc.update_rule AS on_update,
               rc.delete_rule AS on_delete
        FROM information_schema.referential_constraints rc
        INNER JOIN information_schema.key_column_usage fk ON rc.constraint_name = fk.constraint_name
        INNER JOIN information_schema.constraint_column_usage cc ON rc.constraint_name = cc.constraint_name
        WHERE fk.table_name = %<table_name>s
          AND fk.constraint_schema = %<constraint_schema>s
      SQL


      #   fk_info = exec_query(<<~SQL, "SCHEMA")
      #   SELECT fk.table_name AS 'to_table',
      #          fk.column_name AS 'primary_key',
      #          fk.column_name AS 'column',
      #          fk.constraint_name AS 'name',
      #          rc.update_rule AS 'on_update',
      #          rc.delete_rule AS 'on_delete'
      #   FROM information_schema.referential_constraints rc
      #   JOIN information_schema.key_column_usage fk ON fk.
      #   JOIN information_schema.contraint_column_usage cc
      #   USING (constraint_schema, constraint_name)
      #   WHERE fk.table_schema = #{scope[:schema]}
      #     AND fk.table_name = #{scope[:name]}
      #     AND rc.constraint_schema = #{scope[:schema]}
      #     AND rc.table_name = #{scope[:name]}
      #     AND cc.constraint_schema = #{scope[:schema]}
      #     AND cc.table_name = #{scope[:name]}
      # SQL


      #   sql = <<~SQL
      #   SELECT * FROM information_schema.referential_constraints rc
      #     WHERE table_name=%<table_name>s
      #     AND constraint_type=%<constraint_type%>s

      #   SQL
      rows = execute_query(
        sql, table_name: table_name, constraint_schema: ""
      )

      rows.map do |row|
        ForeignKey.new(
          table_name,
          row["name"],
          row["column"],
          row["to_table"],
          row["primary_key"],
          on_delete: row["on_delete"],
          on_update: row["on_update"],
          connection:  @connection
        )
      end
    end

    private

    def execute_query sql, params = {}
      params = params.transform_values { |v| quote v }
      sql = format sql, params

      @mutex.synchronize do
        @connection.snapshot(sql, strong: true).rows
      end
    end
  end
end
