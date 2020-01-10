require "spanner_activerecord/index/column"

module SpannerActiverecord
  class Index
    attr_reader :table, :name, :columns, :type, :unique, :null_filtered,
                :interleve_in, :state

    def initialize \
        connection,
        table,
        name,
        columns,
        type: nil,
        unique: false,
        null_filtered: false,
        interleve_in: nil,
        state: nil
      @connection = connection
      @table = table
      @name = name
      @columns = columns
      @type = type
      @unique = unique
      @null_filtered = null_filtered
      @interleve_in = interleve_in unless interleve_in.to_s.empty?
      @state = state
    end

    def primary?
      @type == "PRIMARY_KEY"
    end

    def primary!
      @type = "PRIMARY_KEY"
    end

    def orders
      @columns.select(&:ordinal_position).sort do |c1, c2|
        c1.ordinal_position <=> c2.ordinal_position
      end
    end

    def storing
      @columns.select { |c| c.ordinal_position.nil? }.sort do |c1, c2|
        c1.ordinal_position <=> c2.ordinal_position
      end
    end

    def create
    end

    def drop
    end

    def rename new_name
    end

    def change
    end
  end
end
