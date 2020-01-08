module SpannerActiverecord
  class Table
    attr_reader :name

    def initalize name, service
      @name = name
      @service = service
    end

    def rename new_name
    end

    def truncate
    end

    def columns
    end

    def drop
    end

    def column column_name
      Column.new name, column_name, service
    end

    def indexes
    end

    def index \
        name,
        columns: [],
        orders: {},
        unique: false,
        null_filtered: nil,
        storing: nil,
        interleve_in: nil
      Index.new \
        table,
        name,
        unique: unique,
        columns: columns,
        orders: orders,
        null_filtered: null_filtered,
        storing: storing,
        interleve_in: interleve_in,
        service: service
    end
  end
end
