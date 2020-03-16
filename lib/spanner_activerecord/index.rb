require "spanner_activerecord/index/column"

module SpannerActiverecord
  class Index
    attr_accessor :table, :name, :columns, :type, :unique, :null_filtered,
                  :interleve_in, :storing, :state

    def initialize \
        table,
        name,
        columns,
        type: nil,
        unique: false,
        null_filtered: false,
        interleve_in: nil,
        storing: nil,
        state: nil
      @table = table.to_s
      @name = name.to_s
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

    def columns_by_position
      @columns.select(&:ordinal_position).sort do |c1, c2|
        c1.ordinal_position <=> c2.ordinal_position
      end
    end

    def orders
      columns_by_position.each_with_object({}) do |c, r|
        r[c.name] = c.desc? ? :desc : :asc
      end
    end
  end
end
