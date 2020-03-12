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

  describe "#create_sql" do
    it "create sql for single column constraint" do
      fk = SpannerActiverecord::ForeignKey.new(
        table_name, contraint_name, column_name,
        ref_table_name, ref_column_name
      )

      assert_sql_equal(
        fk.create_sql,
        "CONSTRAINT #{contraint_name} FOREIGN KEY (#{column_name}) REFERENCES #{ref_table_name} (#{ref_column_name})"
      )
    end

    it "create sql for multiple column constraint" do
      fk = SpannerActiverecord::ForeignKey.new(
        table_name, contraint_name, ["col1", "col2"],
        ref_table_name, ref_column_name
      )

      assert_sql_equal(
        fk.create_sql,
        "CONSTRAINT #{contraint_name} FOREIGN KEY (col1, col2) REFERENCES #{ref_table_name} (#{ref_column_name})"
      )
    end

    it "create sql for multiple column ref columns" do
      fk = SpannerActiverecord::ForeignKey.new(
        table_name, contraint_name, column_name,
        ref_table_name, ["ref-col1", "ref-col2"]
      )

      assert_sql_equal(
        fk.create_sql,
        "CONSTRAINT #{contraint_name} FOREIGN KEY (#{column_name}) REFERENCES #{ref_table_name} (ref-col1, ref-col2)"
      )
    end
  end

  describe "#alter" do
    it "create sql for single column constraint" do
      fk = SpannerActiverecord::ForeignKey.new(
        table_name, contraint_name, column_name,
        ref_table_name, ref_column_name,
        connection: connection
      )

      fk.alter


      assert_sql_equal(
        last_executed_sqls,
        "ALTER TABLE #{table_name} CONSTRAINT #{contraint_name} FOREIGN KEY (#{column_name}) REFERENCES #{ref_table_name} (#{ref_column_name})"
      )
    end
  end
end