module SpannerActiverecord
  class Table
    class Column
      attr_reader :table_name, :name, :type, :nullable, :ordinal_position, \
                  :allow_commit_timestamp

      def initialize \
          connection,
          table_name,
          name,
          type,
          ordinal_position: nil,
          nullable: nil,
          allow_commit_timestamp: nil
        @connection = connection
        @table_name = table_name
        @name = name
        @type = type
        @nullable = nullable
        @ordinal_position = ordinal_position
        @allow_commit_timestamp = allow_commit_timestamp
      end
    end

    def nullable?
      @nullable == "YES"
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
