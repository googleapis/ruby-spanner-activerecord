require "spanner_activerecord/table/column"

module SpannerActiverecord
  class Table
    attr_accessor :name, :on_delete, :parent_table, :schema_name, :catalog

    # parent_table == interleave_in
    def initialize \
        name,
        parent_table: nil,
        on_delete: nil,
        schema_name: nil,
        catalog: nil,
        connection: nil
      @connection = connection
      @name = name.to_s
      @parent_table = parent_table.to_s if parent_table
      @on_delete = on_delete
      @schema_name = schema_name
      @catalog = catalog
      @columns_hash = {}
      @indexes_hash = {}
    end

    def indexes
      @indexes_hash.values
    end

    def indexes= values
      @indexes_hash = values.each_with_object({}) do |index, r|
        r[index.name] = index
      end
    end

    def columns
      @columns_hash.values
    end

    def columns= values
      @columns_hash = values.each_with_object({}) do |column, r|
        r[column.name] = column
      end
    end

    def add_column \
        column_name,
        type,
        limit: nil,
        nullable: false,
        allow_commit_timestamp: false
      @columns_hash[column_name] = Table::Column.new(
        name,
        column_name,
        type,
        limit: limit,
        nullable: nullable,
        allow_commit_timestamp: allow_commit_timestamp,
        connection: @connection
      )
    end

    def alter
      statements = columns.map(&:add_sql).flatten
      @connection.execute_ddl statements if statements.any?
    end

    def add_index \
        index_name,
        columns,
        unique: false,
        null_filtered: false,
        interleve_in: nil,
        storing: nil
      columns = columns.map do |column, order|
        Index::Column.new \
          name,
          index_name,
          column,
          order: order,
          connection: @connection
      end

      index = Index.new \
        name,
        index_name,
        columns,
        unique: unique,
        null_filtered: null_filtered,
        interleve_in: interleve_in,
        storing: storing,
        connection: @connection
      @indexes_hash[index_name] = index
    end

    def primary_keys= columns
      columns = Array(columns).map(&:to_s)
      @columns_hash.each do |_, c|
        c.primary_key = columns.include? c.name
      end
    end

    def primary_keys
      columns.select(&:primary_key).map(&:name)
    end

    def cascade?
      @on_delete == "CASCADE"
    end

    def rename _new_name
      raise NotSupportedError, "rename of table not supported"
    end

    def drop
      @connection.execute_ddl drop_table_sql
    end

    def drop_table_sql
      statements = drop_indexs_sql
      statements << "DROP TABLE #{name}"
      statements
    end

    def drop_indexes
      @connection.execute_ddl drop_indexs_sql
    end

    def drop_indexs_sql
      indexes.each_with_object [] do |index, r|
        r << index.drop_sql unless index.primary?
      end
    end

    def create drop_table: nil
      statements = []

      if drop_table
        existing_table = information_schema.table name, view: :indexes
        statements.concat existing_table.drop_table_sql if existing_table
      end

      statements.concat create_sql
      statements.concat indexes_sql
      @connection.execute_ddl statements
    end

    def create_sql
      statements = []
      columns_sql = columns.map(&:new_column_sql)
      sql = +"CREATE TABLE #{name}(\n  #{columns_sql.join ",\n  "} \n)"
      sql << " PRIMARY KEY(#{primary_keys.join ', '})" if primary_keys.any?

      if parent_table
        sql << ", INTERLEAVE IN PARENT #{parent_table}"
        sql << " ON DELETE CASCADE" if cascade?
      end

      statements << sql
      statements
    end

    def indexes_sql
      indexes.each_with_object [] do |i, r|
        r << i.create_sql unless i.primary?
      end
    end

    def reference_indexes_sql
      columns.each_with_object [] do |c, r|
        r << c.reference_index.create_sql if c.reference_index
      end
    end

    def cascade_change
      @connection.execute_ddl cascade_change_sql
    end

    def cascade_change_sql
      value = cascade? ? "CASCADE" : "NO ACTION"
      "ALTER TABLE #{name} SET ON DELETE #{value}"
    end

    private

    def information_schema
      InformationSchema.new @connection
    end
  end
end
