require "test_helper"

class InformationSchemaForeignKeyTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :column_name, :contraint_name,
    :ref_table_name, :ref_column_name

  def setup
    @table_name = "test-table"
    @column_name = "test-column"
    @contraint_name = "test-contraint"
    @ref_table_name = "test-ref-table"
    @ref_column_name = "test-ref-column"
  end

  def test_create_instance_of_foreign_key
    fk = SpannerActiverecord::ForeignKey.new(
      table_name, contraint_name, column_name,
      ref_table_name, ref_column_name
    )

    assert_equal fk.table_name, table_name
    assert_equal fk.columns, [column_name]
    assert_equal fk.name, contraint_name
    assert_equal fk.ref_table, ref_table_name
    assert_equal fk.ref_columns, [ref_column_name]
  end
end
