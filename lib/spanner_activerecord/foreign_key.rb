module SpannerActiverecord
  class ForeignKey
    attr_accessor :table_name, :name, :columns, :ref_table, :ref_columns,
                  :on_delete, :on_update

    def initialize \
        table_name,
        name,
        columns,
        ref_table,
        ref_columns,
        on_delete: nil,
        on_update: nil,
        connection: nil
      @table_name = table_name
      @name = name
      @columns = Array(columns)
      @ref_table = ref_table
      @ref_columns = Array(ref_columns)
      @on_delete = on_delete
      @on_update = on_update
      @connection = connection
    end

    def create_sql
      "CONSTRAINT #{name} FOREIGN KEY (#{@columns.join ', '})" \
      " REFERENCES #{ref_table} (#{ref_columns.join ', '})"
    end

    def alter_sql
      "ALTER TABLE #{table_name} #{create_sql}"
    end

    def alter
      @connection.execute_ddl alter_sql
    end

    def drop_sql
      "ALTER TABLE #{table_name} DROP CONSTRAINT #{name}"
    end

    def drop
      @connection.execute_ddl drop_sql
    end
  end
end
