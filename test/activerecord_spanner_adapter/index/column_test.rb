require "test_helper"

class InformationSchemaIndexColumnTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :column_name, :index_name

  def setup
    super
    @table_name = "test-table"
    @column_name = "test-column"
    @index_name = "index-name"
  end

  def test_create_index_column_instance
    column = ActiveRecordSpannerAdapter::Index::Column.new(
      table_name, index_name, column_name,
      order: "DESC", ordinal_position: 1
    )

    assert_equal column.name, column_name
    assert_equal column.table_name, table_name
    assert_equal column.index_name, index_name
    assert_equal column.order, "DESC"
    assert_equal column.desc?, true
    assert_equal column.ordinal_position, 1
    assert_equal column.storing?, false
  end
end
