module SpannerActiverecord
  class Index
    # INFORMATION_SCHEMA.INDEX_COLUMNS
    Column = Struct.new :name, :order, :ordinal_position

    attr_reader :table, :name, :unique, :columns, :orders,
                :null_filtered, :storing, :interleve_in

    def initialize \
        table,
        name,
        unique: false,
        columns: [],
        orders: {},
        null_filtered: nil,
        storing: nil,
        interleve_in: nil,
        service: nil
      @table = table
      @name = name
      @unique = unique
      @columns = Array(columns)
      @orders = orders
      @null_filtered = null_filtered
      @storing = storing
      @interleve_in = interleve_in
      @service = service
    end

    def create
    end

    def drop
    end

    def rename new_name
    end

    def index_columns
    end
  end
end
