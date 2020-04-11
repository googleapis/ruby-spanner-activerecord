module ActiveRecordSpannerAdapter
  class ForeignKey
    attr_accessor :table_name, :name, :columns, :ref_table, :ref_columns,
                  :on_delete, :on_update

    def initialize \
        table_name,
        name,
        columns,
        ref_table,
        ref_columns,
        on_delete: nil,
        on_update: nil
      @table_name = table_name
      @name = name
      @columns = Array(columns)
      @ref_table = ref_table
      @ref_columns = Array(ref_columns)
      @on_delete = on_delete unless on_delete == "NO ACTION"
      @on_update = on_update unless on_update == "NO ACTION"
    end
  end
end
