require "spanner_activerecord/index/column"

module SpannerActiverecord
  class Index
    attr_reader :table, :name, :columns, :type, :unique, :null_filtered,
                :interleve_in, :storing, :state

    def initialize \
        connection,
        table,
        name,
        columns,
        type: nil,
        unique: false,
        null_filtered: false,
        interleve_in: nil,
        storing: nil,
        state: nil
      @connection = connection
      @table = table
      @name = name
      @columns = Array(columns)
      @type = type
      @unique = unique
      @null_filtered = null_filtered
      @interleve_in = interleve_in unless interleve_in.to_s.empty?
      @storing = storing || []
      @state = state
    end

    def primary?
      @type == "PRIMARY_KEY"
    end

    def primary!
      @type = "PRIMARY_KEY"
    end

    def orders_columns
      @columns.select(&:ordinal_position).sort do |c1, c2|
        c1.ordinal_position <=> c2.ordinal_position
      end
    end

    def orders
      orders_columns.each_with_object({}) do |c, r|
        r[c.name] = c.desc? ? :desc : :asc
      end
    end

    def create
      @connection.execute_ddl create_sql
    end

    def create_sql
      sql = +"CREATE"
      sql << " UNIQUE" if unique
      sql << " NULL_FILTERED" if null_filtered
      sql << " INDEX #{name} "

      columns_sql = columns.map do |c|
        c.desc? ? "#{c.name} DESC" : c.name
      end

      sql << "ON #{table} (#{columns_sql.join ', '})"
      sql << " STORING (#{storing.join ', '})" if storing.any?
      sql << ", INTERLEAVE IN #{interleve_in}" if interleve_in
      sql
    end

    def drop
      @connection.execute_ddl drop_sql
    end

    def drop_sql
      "DROP INDEX #{name}"
    end

    def rename _new_name
      raise SpannerActiverecord::NotSupoorted, "rename of index not supported"
    end
  end
end
