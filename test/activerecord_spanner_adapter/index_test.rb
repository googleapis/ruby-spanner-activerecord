require "test_helper"

class InformationSchemaIndexTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :parent_table_name, :index_name

  def setup
    super
    @table_name = "test-table"
    @parent_table_name = "test-parent-table"
    @index_name = "test-index"
  end


  def test_create_instance_of_index
    column1 = new_index_column(
      table_name: table_name, index_name:  index_name, column_name: "col1",
      order: "DESC", ordinal_position: 1
    )
    column2 = new_index_column(
      table_name: table_name, index_name:  index_name, column_name: "col2",
      ordinal_position: 0
    )

    index = ActiveRecordSpannerAdapter::Index.new(
      table_name, index_name, [column1, column2],
      unique: true, storing: ["col1"]
    )

    assert_equal index.table, table_name
    assert_equal index.name, index_name
    assert_equal index.columns, [column1, column2]
    assert_equal index.unique, true
    assert_equal index.storing,  ["col1"]
    assert_equal index.primary?, false
    assert_equal index.columns_by_position, [column2, column1]
    assert_equal index.orders, ({ "col1" => :desc, "col2" => :asc})
  end
end
