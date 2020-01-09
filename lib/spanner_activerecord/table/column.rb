module SpannerActiverecord
  class Table
    class Column
      attr_reader :table_name, :name, :type, :nullable, :ordinal_position

      def initialize \
          connection,
          table_name,
          name,
          type,
          ordinal_position: nil,
          nullable: nil
        @connection = connection
        @table_name = table_name
        @name = name
        @type = type
        @nullable = nullable
        @ordinal_position = ordinal_position
      end
    end

    def add
    end

    def remove
    end

    def change
    end

    def rename
    end
  end
end
