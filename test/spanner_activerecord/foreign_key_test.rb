require "test_helper"

describe SpannerActiverecord::ForeignKey, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:column_name) { "test-column" }
  let(:contraint_name) { "test-contraint"}
  let(:ref_table_name) { "test-ref-table" }
  let(:ref_column_name) { "test-ref-column" }

  describe "#new" do
    it "create a instance of foreign key" do
      fk = SpannerActiverecord::ForeignKey.new(
        table_name, contraint_name, column_name,
        ref_table_name, ref_column_name
      )

      fk.table_name.must_equal table_name
      fk.columns.must_equal [column_name]
      fk.name.must_equal contraint_name
      fk.ref_table.must_equal ref_table_name
      fk.ref_columns.must_equal [ref_column_name]
    end
  end
end