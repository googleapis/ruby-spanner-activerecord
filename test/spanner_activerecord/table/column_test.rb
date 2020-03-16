require "test_helper"

describe SpannerActiverecord::Table::Column, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:column_name) { "test-column" }
  let(:reference_index_name) { "test-reference-index"}

  describe "#new" do
    it "create a instance of table column" do
      column = SpannerActiverecord::Table::Column.new(
        table_name, column_name, "STRING",
        limit: 255, ordinal_position: 1, nullable: true,
        allow_commit_timestamp: true,
      )

      column.name.must_equal column_name
      column.table_name.must_equal table_name
      column.type.must_equal "STRING"
      column.limit.must_equal 255
      column.ordinal_position.must_equal 1
      column.nullable.must_equal true
      column.allow_commit_timestamp.must_equal true
      column.primary_key.must_equal false
    end
  end

  describe "#primary_key" do
    it "set column as primary key column" do
      column = new_table_column
      column.primary_key.must_equal false
      column.primary_key = true
      column.primary_key.must_equal true
    end
  end

  describe "#nullable" do
    it "nullable for non primary key column" do
      column = new_table_column
      column.primary_key = false
      column.nullable.must_equal true
    end

    it "not nullable for primary key column" do
      column = new_table_column
      column.primary_key = true
      column.nullable.must_equal false
    end
  end

  describe "#spanner_type" do
    it "returns spanner type for integer" do
      column = new_table_column type: "INT64"
      column.spanner_type.must_equal "INT64"

      column = new_table_column type: "INT64", limit: 10000
      column.spanner_type.must_equal "INT64"
    end

    it "returns spanner type for float" do
      column = new_table_column type: "FLOAT64"
      column.spanner_type.must_equal "FLOAT64"

      column = new_table_column type: "FLOAT64", limit: 10000
      column.spanner_type.must_equal "FLOAT64"
    end

    it "returns spanner type for bool" do
      column = new_table_column type: "BOOL"
      column.spanner_type.must_equal "BOOL"

      column = new_table_column type: "BOOL", limit: 1
      column.spanner_type.must_equal "BOOL"
    end

    it "returns spanner type for string" do
      column = new_table_column type: "STRING"
      column.spanner_type.must_equal "STRING(MAX)"

      column = new_table_column type: "STRING", limit: 1024
      column.spanner_type.must_equal "STRING(1024)"
    end

    it "returns spanner type for bytes" do
      column = new_table_column type: "BYTES"
      column.spanner_type.must_equal "BYTES(MAX)"

      column = new_table_column type: "BYTES", limit: 1024
      column.spanner_type.must_equal "BYTES(1024)"
    end

    it "returns spanner type for date" do
      column = new_table_column type: "DATE"
      column.spanner_type.must_equal "DATE"

      column = new_table_column type: "DATE", limit: 1024
      column.spanner_type.must_equal "DATE"
    end

    it "returns spanner type for timestamp" do
      column = new_table_column type: "TIMESTAMP"
      column.spanner_type.must_equal "TIMESTAMP"

      column = new_table_column type: "TIMESTAMP", limit: 1024
      column.spanner_type.must_equal "TIMESTAMP"
    end
  end
end