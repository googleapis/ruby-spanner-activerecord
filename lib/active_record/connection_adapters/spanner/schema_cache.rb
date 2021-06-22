module ActiveRecord
  module ConnectionAdapters
    class SpannerSchemaCache < SchemaCache
      def initialize conn
        @primary_and_parent_keys = {}
        super
      end

      def initialize_dup other
        @primary_and_parent_keys = @primary_and_parent_keys.dup
        super
      end

      def encode_with coder
        coder["primary_and_parent_keys"] = @primary_and_parent_keys
        super
      end

      def init_with coder
        @primary_and_parent_keys = coder["primary_and_parent_keys"]
        super
      end

      def primary_and_parent_keys table_name
        @primary_and_parent_keys[table_name] ||=
          if data_source_exists? table_name
            connection.primary_and_parent_keys table_name
          end
      end

      def clear!
        @primary_and_parent_keys.clear
        super
      end
    end
  end
end
