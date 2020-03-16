require "test_helper"

describe SpannerActiverecord::Index, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:column_name) { "test-column" }
  let(:index_name) { "test-index"}

  describe "#new" do
    it "create a instance of index" do
      column1 = new_index_column(
        table_name: table_name, index_name:  index_name, column_name: "col1",
        order: "DESC", ordinal_position: 1
      )
      column2 = new_index_column(
        table_name: table_name, index_name:  index_name, column_name: "col2",
        ordinal_position: 0
      )

      index = SpannerActiverecord::Index.new(
        table_name, index_name, [column1, column2],
        unique: true, storing: ["col1"]
      )

      index.table.must_equal table_name
      index.name.must_equal index_name
      index.columns.must_equal [column1, column2]
      index.unique.must_equal true
      index.storing.must_equal  ["col1"]
      index.primary?.must_equal false
      index.columns_by_position.must_equal [column2, column1]
      index.orders.must_equal({ "col1" => :desc, "col2" => :asc})
    end
  end
end