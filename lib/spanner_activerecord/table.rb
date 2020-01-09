module SpannerActiverecord
  class Table
    attr_reader :name, :parent_table, :on_delete, :schema_name, :catalog

    def initalize \
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

    def create
    end

    def rename new_name
    end

    def truncate
    end

    def drop
    end

    def columns
      information_schema.columns
    end

    def column column_name
      # Column.new name, column_name, service
    end

    def indexes
    end

    def index name
    end

    private

    def information_schema
      @information_schema ||= InformationSchema.new @connection
    end
  end
end
