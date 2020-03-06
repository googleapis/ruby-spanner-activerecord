require "test_helper"

describe SpannerActiverecord::InformationSchema, :mock_spanner_activerecord  do
  let(:info_schema) { SpannerActiverecord::InformationSchema.new connection }
  let(:tables_schema_result) {
    [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "PARENT_TABLE_NAME" => nil,
        "ON_DELETE_ACTION" => nil,
        "SPANNER_STATE" => "COMMITTED"
      }
    ]
  }
  let(:table_columns_result) {
    [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "COLUMN_NAME" => "account_id",
        "ORDINAL_POSITION" => 1,
        "COLUMN_DEFAULT" => nil,
        "DATA_TYPE" => nil,
        "IS_NULLABLE" => "NO",
        "SPANNER_TYPE" => "INT64"
      },
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "COLUMN_NAME" => "name",
        "ORDINAL_POSITION" => 2,
        "COLUMN_DEFAULT" => nil,
        "DATA_TYPE" => nil,
        "IS_NULLABLE" => "YES",
        "SPANNER_TYPE" => "STRING(32)"
      }
    ]
  }
  let(:indexes_result){
    [
      {
        "TABLE_CATALOG" =>"",
        "TABLE_SCHEMA" =>"",
        "TABLE_NAME" => "orders",
        "INDEX_NAME" => "index_orders_on_user_id",
        "INDEX_TYPE" => "INDEX",
        "PARENT_TABLE_NAME" => "",
        "IS_UNIQUE" => false,
        "IS_NULL_FILTERED" => false,
        "INDEX_STATE" => "READ_WRITE",
        "SPANNER_IS_MANAGED" => false
      }
    ]
  }
  let(:index_columns_result){
    [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "orders",
        "INDEX_NAME" => "index_orders_on_user_id",
        "INDEX_TYPE" => "INDEX",
        "COLUMN_NAME" => "user_id",
        "ORDINAL_POSITION" => 1,
        "COLUMN_ORDERING" => "ASC",
        "IS_NULLABLE" => "YES",
        "SPANNER_TYPE" => "INT64"
      }
    ]
  }

  describe "#new" do
    it "create an instance" do
      info_schema = SpannerActiverecord::InformationSchema.new connection
      info_schema.must_be_instance_of SpannerActiverecord::InformationSchema
    end
  end

  describe "#tables" do
    it "list all tables" do
      set_mocked_result tables_schema_result
      result = info_schema.tables
      result.length.must_equal 1

      assert_sql_equal(
        last_executed_sql,
        "SELECT * FROM information_schema.tables WHERE table_schema=''"
      )

      result.each do |table|
        table.must_be_instance_of SpannerActiverecord::Table
      end

      table = result.first
      table.name.must_equal "accounts"
    end

    it "list all tables with columns view" do
      set_mocked_result tables_schema_result
      info_schema.tables view: :columns

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema=''",
          "SELECT * FROM information_schema.columns WHERE table_name='accounts'"
        ]
      )
    end

    it "list all tables with indexes view" do
      set_mocked_result tables_schema_result
      info_schema.tables view: :indexes

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema=''",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end

    it "list all tables with full view" do
      set_mocked_result tables_schema_result
      info_schema.tables view: :full

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema=''",
          "SELECT * FROM information_schema.columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end
  end

  describe "#table" do
    it "get table" do
      set_mocked_result tables_schema_result
      table = info_schema.table "accounts"
      table.must_be_instance_of SpannerActiverecord::Table

      assert_sql_equal(
        last_executed_sql,
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'"
      )
    end

    it "get table with columns view" do
      set_mocked_result tables_schema_result
      info_schema.table "accounts", view: :columns

      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
        "SELECT * FROM information_schema.columns WHERE table_name='accounts'"
      )
    end

    it "get table with indexes view" do
      set_mocked_result tables_schema_result
      info_schema.table "accounts", view: :indexes

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end

    it "get table with full view" do
      set_mocked_result tables_schema_result
      info_schema.table "accounts", view: :full

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
          "SELECT * FROM information_schema.columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end
  end

  describe "#table_columns" do
    it "list table columns" do
      set_mocked_result table_columns_result
      result = info_schema.table_columns "accounts"
      result.length.must_equal 2

      assert_sql_equal(
        last_executed_sql,
        "SELECT * FROM information_schema.columns WHERE table_name='accounts'"
      )

      result.each do |column|
        column.must_be_instance_of SpannerActiverecord::Table::Column
      end

      column1 = result[0]
      column1.table_name.must_equal "accounts"
      column1.name.must_equal "account_id"
      column1.type.must_equal "INT64"
      column1.limit.must_be_nil
      column1.nullable.must_equal false

      column2 = result[1]
      column2.table_name.must_equal "accounts"
      column2.name.must_equal "name"
      column2.type.must_equal "STRING"
      column2.limit.must_equal 32
      column2.nullable.must_equal true
    end
  end

  describe "#table_column" do
    it "get table column" do
      set_mocked_result table_columns_result
      column = info_schema.table_column "accounts", "account_id"
      column.must_be_instance_of SpannerActiverecord::Table::Column

      assert_sql_equal(
        last_executed_sql,
        "SELECT * FROM information_schema.columns WHERE table_name='accounts' AND column_name='account_id'"
      )
    end
  end

  describe "#indexes" do
    it "list table indexes" do
      set_mocked_result index_columns_result
      set_mocked_result indexes_result
      result = info_schema.indexes "orders"
      result.length.must_equal 1

      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.index_columns WHERE table_name='orders'",
        "SELECT * FROM information_schema.indexes WHERE table_name='orders'"
      )

      result.each do |index|
        index.must_be_instance_of SpannerActiverecord::Index
      end

      index = result[0]
      index.table.must_equal "orders"
      index.name.must_equal "index_orders_on_user_id"
      index.unique.must_equal false
      index.null_filtered.must_equal false
      index.interleve_in.must_be_nil
      index.storing.must_equal []
      index.columns.length.must_equal 1
      index.columns.each do |column|
        column.must_be_instance_of SpannerActiverecord::Index::Column
      end

      column = index.columns.first
      column.name.must_equal "user_id"
    end
  end

  describe "#index" do
    it "get an index" do
      set_mocked_result index_columns_result
      set_mocked_result indexes_result
      index = info_schema.index "orders", "index_orders_on_user_id"
      index.must_be_instance_of SpannerActiverecord::Index

      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.index_columns WHERE table_name='orders' AND index_name='index_orders_on_user_id'",
        "SELECT * FROM information_schema.indexes WHERE table_name='orders' AND index_name='index_orders_on_user_id'"
      )

      index.table.must_equal "orders"
      index.name.must_equal "index_orders_on_user_id"
      index.unique.must_equal false
      index.null_filtered.must_equal false
      index.interleve_in.must_be_nil
      index.storing.must_equal []
      index.columns.length.must_equal 1
      index.columns.each do |column|
        column.must_be_instance_of SpannerActiverecord::Index::Column
      end

      column = index.columns.first
      column.name.must_equal "user_id"
    end
  end

  describe "#index_columns" do
    it "list an index columns" do
      set_mocked_result index_columns_result
      result = info_schema.index_columns "orders", index_name: "index_orders_on_user_id"
      result.length.must_equal 1

      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.index_columns WHERE table_name='orders' AND index_name='index_orders_on_user_id'"
      )

      column = result.first
      column.table_name.must_equal "orders"
      column.index_name.must_equal "index_orders_on_user_id"
      column.name.must_equal "user_id"
      column.order.must_equal "ASC"
    end
  end

  describe "#indexes_by_columns" do
    it "list indexes for given columns list" do
      set_mocked_result index_columns_result
      set_mocked_result indexes_result
      result = info_schema.indexes_by_columns "orders", ["user_id"]
      result.length.must_equal 1

      index = result.first
      index.name.must_equal "index_orders_on_user_id"
      index.columns.any?{ |c| c.name == "user_id"}.must_equal true
    end
  end
end