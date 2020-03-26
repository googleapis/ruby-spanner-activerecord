require "test_helper"

class InformationSchemaTableTest < TestHelper::MockActiveRecordTest
  attr_reader :table_name, :parent_table_name

  def setup
    super
    @table_name = "test-table"
    @parent_table_name = "test-parent-table"
  end

  def test_create_a_instance_of_table
    column1 = new_table_column(
      table_name: table_name, column_name: "id", type: "STRING", limit: 36
    )
    column1.primary_key = true
    column2 = new_table_column(
      table_name: table_name, column_name: "DESC", type: "STRING", limit: "MAX"
    )

    table = ActiveRecordSpannerAdapter::Table.new(
      table_name,
      parent_table: parent_table_name,
      on_delete: "CASCADE",
      schema_name: "",
      catalog: ""
    )

    table.columns = [column1, column2]

    assert_equal table.name, table_name
    assert_equal table.parent_table, parent_table_name
    assert_equal table.on_delete, "CASCADE"
    assert_equal table.cascade?, true
    assert_empty table.catalog
    assert_empty table.schema_name
    assert_equal table.columns.length, 2
    assert_equal table.primary_keys, ["id"]
  end
end
