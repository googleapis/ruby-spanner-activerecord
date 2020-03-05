require "test_helper"

describe SpannerActiverecord::Table, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:parent_table_name) { "test-parent-table" }

  describe "#new" do
    it "create a instance of table" do
      table = SpannerActiverecord::Table.new(
        table_name,
        parent_table: parent_table_name,
        on_delete: "CASCADE",
        schema_name: "",
        catalog: "",
        connection: connection
      )

      table.name.must_equal table_name
      table.parent_table.must_equal  parent_table_name
      table.on_delete.must_equal "CASCADE"
      table.catalog.must_be_empty
      table.schema_name.must_be_empty
      table.instance_variable_get("@connection").wont_be :nil?
    end
  end

  describe "#create" do
  end

  describe "#drop" do
  end

  describe "#alter" do
  end
end