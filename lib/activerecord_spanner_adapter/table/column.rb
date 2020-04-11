module ActiveRecordSpannerAdapter
  class Table
    class Column
      attr_accessor :table_name, :name, :type, :limit, :ordinal_position,
                    :allow_commit_timestamp, :default, :primary_key
      attr_writer :nullable

      def initialize \
          table_name,
          name,
          type,
          limit: nil,
          ordinal_position: nil,
          nullable: true,
          allow_commit_timestamp: nil,
          default: nil
        @table_name = table_name.to_s
        @name = name.to_s
        @type = type
        @limit = limit
        @nullable = nullable != false
        @ordinal_position = ordinal_position
        @allow_commit_timestamp = allow_commit_timestamp
        @default = default
        @primary_key = false
      end

      def nullable
        return false if primary_key
        @nullable
      end

      def spanner_type
        return "#{type}(#{limit || 'MAX'})" if limit_allowed?
        type
      end

      def options
        {
          limit: limit,
          null: nullable,
          allow_commit_timestamp: allow_commit_timestamp
        }.delete_if { |_, v| v.nil? }
      end

      private

      def limit_allowed?
        ["BYTES", "STRING"].include? type
      end
    end
  end
end
