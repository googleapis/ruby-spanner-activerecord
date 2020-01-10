require "spanner_activerecord/table/column"

module SpannerActiverecord
  class Table
    attr_reader :name, :on_delete, :parent_table, :schema_name, :catalog

    # parent_table == interleave_in
    def initialize \
        connection,
        name,
        parent_table: nil,
        on_delete: nil,
        schema_name: nil,
        catalog: nil
      @connection = connection
      @name = name
      @parent_table = parent_table
      @on_delete = on_delete
      @schema_name = schema_name
      @catalog = catalog
    end

    def columns force: false
      if force || @columns.nil?
        @columns ||= information_schema.table_columns name
      end
      @columns
    end

    def indexes force: false
      if force || @indexes.nil?
        @indexes ||= information_schema.indexes name
      end
      @indexes
    end

    def primary_key
      indexes.find(&:primary?)&.columns&.map(&:name)
    end

    def cascade?
      @on_delete == "CASCADE"
    end

    def create
    end

    def rename new_name
    end

    def truncate
    end

    def drop
    end

    private

    def information_schema
      InformationSchema.new @connection
    end
  end
end
