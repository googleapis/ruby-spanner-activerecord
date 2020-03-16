require "test_helper"

describe SpannerActiverecord::Index::Column, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:column_name) { "test-column" }
  let(:index_name) { "test-index"}

  describe "#new" do
    it "create a instance of index column" do
      column = SpannerActiverecord::Index::Column.new(
        table_name, index_name, column_name,
        order: "DESC", ordinal_position: 1
      )

      column.name.must_equal column_name
      column.table_name.must_equal table_name
      column.index_name.must_equal index_name
      column.order.must_equal "DESC"
      column.desc?.must_equal true
      column.ordinal_position.must_equal 1
      column.storing?.must_equal false
    end
  end
end