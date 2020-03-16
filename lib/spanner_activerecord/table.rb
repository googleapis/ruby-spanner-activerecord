require "spanner_activerecord/table/column"

module SpannerActiverecord
  class Table
    attr_accessor :name, :on_delete, :parent_table, :schema_name, :catalog,
                  :indexes, :columns, :foreign_keys

    # parent_table == interleave_in
    def initialize \
        name,
        parent_table: nil,
        on_delete: nil,
        schema_name: nil,
        catalog: nil
      @name = name.to_s
      @parent_table = parent_table.to_s if parent_table
      @on_delete = on_delete
      @schema_name = schema_name
      @catalog = catalog
      @columns = []
      @indexes = []
      @foreign_keys = []
    end

    def primary_keys
      columns.select(&:primary_key).map(&:name)
    end

    def cascade?
      @on_delete == "CASCADE"
    end
  end
end
