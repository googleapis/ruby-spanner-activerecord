require "test_helper"

describe SpannerActiverecord::Table, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:parent_table_name) { "test-parent-table" }

  describe "#new" do
    it "create a instance of table" do
      column1 = new_table_column(
        table_name: table_name, column_name: "id", type: "STRING", limit: 36
      )
      column1.primary_key = true
      column2 = new_table_column(
        table_name: table_name, column_name: "DESC", type: "STRING", limit: "MAX"
      )

      table = SpannerActiverecord::Table.new(
        table_name,
        parent_table: parent_table_name,
        on_delete: "CASCADE",
        schema_name: "",
        catalog: ""
      )
      table.columns = [column1, column2]

      table.name.must_equal table_name
      table.parent_table.must_equal  parent_table_name
      table.on_delete.must_equal "CASCADE"
      table.cascade?.must_equal true
      table.catalog.must_be_empty
      table.schema_name.must_be_empty
      table.columns.length.must_equal 2
      table.primary_keys.must_equal ["id"]
    end
  end
end