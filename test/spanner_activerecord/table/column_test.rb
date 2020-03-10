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
        reference_index_name: reference_index_name, connection: connection
      )

      column.name.must_equal column_name
      column.table_name.must_equal table_name
      column.type.must_equal "STRING"
      column.limit.must_equal 255
      column.ordinal_position.must_equal 1
      column.nullable.must_equal true
      column.allow_commit_timestamp.must_equal true
      column.reference_index.name.must_equal reference_index_name
      column.primary_key.must_equal false
      column.instance_variable_get("@connection").wont_be :nil?
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

    it "returns spanner type for UUID" do
      column = new_table_column type: "UUID"
      column.spanner_type.must_equal "STRING(36)"

      column = new_table_column type: "UUID", limit: 1024
      column.spanner_type.must_equal "STRING(36)"
    end
  end

  describe "#parse_type_and_limit" do
    it "returns type and limit" do
      type, limit = SpannerActiverecord::Table::Column.parse_type_and_limit "STRING(MAX)"
      type.must_equal "STRING"
      limit.must_equal "MAX"

      type, limit = SpannerActiverecord::Table::Column.parse_type_and_limit "STRING(1024)"
      type.must_equal "STRING"
      limit.must_equal 1024

      type, limit = SpannerActiverecord::Table::Column.parse_type_and_limit "INT64"
      type.must_equal "INT64"
      limit.must_be :nil?
    end
  end

  describe "#add" do
    describe "Integer" do
      it "add column with default null" do
        column = new_table_column table_name: "users", column_name: "address_id", type: "INT64"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD address_id INT64"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "address_id", type: "INT64",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD address_id INT64 NOT NULL"
        )
      end

      it "add column will ignore limit value" do
        column = new_table_column(
          table_name: "users", column_name: "address_id", type: "INT64",
          limit: 65000
        )
        column.limit.must_be :nil?
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD address_id INT64"
        )
      end
    end

    describe "Float" do
      it "add column with default null" do
        column = new_table_column table_name: "users", column_name: "height", type: "FLOAT64"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD height FLOAT64"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "height", type: "FLOAT64",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD height FLOAT64 NOT NULL"
        )
      end

      it "add column will ignore limit value" do
        column = new_table_column(
          table_name: "users", column_name: "height", type: "INT64",
          limit: 100
        )
        column.limit.must_be :nil?
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD height INT64"
        )
      end
    end

    describe "String" do
      it "add column with default null and default limit MAX" do
        column = new_table_column table_name: "users", column_name: "username", type: "STRING"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD username STRING(MAX)"
        )
      end

      it "add column with limit" do
        column = new_table_column(
          table_name: "users", column_name: "username", type: "STRING", limit: 255
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD username STRING(255)"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "username", type: "STRING",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD username STRING(MAX) NOT NULL"
        )
      end
    end

    describe "Bytes" do
      it "add column with default null and default limit MAX" do
        column = new_table_column table_name: "users", column_name: "photo", type: "BYTES"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD photo BYTES(MAX)"
        )
      end

      it "add column with limit" do
        column = new_table_column(
          table_name: "users", column_name: "photo", type: "BYTES", limit: 2048
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD photo BYTES(2048)"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "photo", type: "BYTES",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD photo BYTES(MAX) NOT NULL"
        )
      end
    end

    describe "Boolean" do
      it "add column" do
        column = new_table_column table_name: "users", column_name: "active", type: "BOOL"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD active BOOL"
        )
      end

      it "add column will ignore limit" do
        column = new_table_column(
          table_name: "users", column_name: "active", type: "BOOL",
          limit: 1
        )
        column.limit.must_be :nil?
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD active BOOL"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "active", type: "BOOL",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD active BOOL NOT NULL"
        )
      end
    end

    describe "Date" do
      it "add column" do
        column = new_table_column table_name: "users", column_name: "registered_date", type: "DATE"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD registered_date DATE"
        )
      end

      it "add column will ignore limit" do
        column = new_table_column(
          table_name: "users", column_name: "registered_date", type: "DATE",
          limit: 1
        )
        column.limit.must_be :nil?
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD registered_date DATE"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "registered_date", type: "DATE",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD registered_date DATE NOT NULL"
        )
      end
    end

    describe "Timestamp" do
      it "add column" do
        column = new_table_column table_name: "users", column_name: "created_at", type: "TIMESTAMP"
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD created_at TIMESTAMP"
        )
      end

      it "add column will ignore limit" do
        column = new_table_column(
          table_name: "users", column_name: "created_at", type: "TIMESTAMP",
          limit: 1
        )
        column.limit.must_be :nil?
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD created_at TIMESTAMP"
        )
      end

      it "add column with default not null" do
        column = new_table_column(
          table_name: "users", column_name: "created_at", type: "TIMESTAMP",
          nullable: false
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD created_at TIMESTAMP NOT NULL"
        )
      end

      it "add column with allow commit timestamp " do
        column = new_table_column(
          table_name: "users", column_name: "created_at", type: "TIMESTAMP",
          allow_commit_timestamp: true
        )
        column.add

        assert_sql_equal(
          last_executed_sqls,
          "ALTER TABLE users ADD created_at TIMESTAMP OPTIONS (allow_commit_timestamp=true)"
        )
      end
    end
  end

  describe "#rename" do
    it "does not support rename" do
      column = new_table_column

      proc{
        column.rename "new-name"
      }.must_raise SpannerActiverecord::NotSupportedError
    end
  end

  describe "#drop" do
    it "drop column without indexes" do
      column = new_table_column table_name: "users", column_name: "address_id"
      column.drop

      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.index_columns WHERE table_name='users'",
        "SELECT * FROM information_schema.indexes WHERE table_name='users'",
        "ALTER TABLE users DROP COLUMN address_id"
      )
    end

    it "drop column and associated indexes" do
      indexes_result = [
        {
          "TABLE_CATALOG" =>"",
          "TABLE_SCHEMA" =>"",
          "TABLE_NAME" => "users",
          "INDEX_NAME" => "index_users_on_address_id",
          "INDEX_TYPE" => "INDEX",
          "PARENT_TABLE_NAME" => "",
          "IS_UNIQUE" => false,
          "IS_NULL_FILTERED" => false,
          "INDEX_STATE" => "READ_WRITE",
          "SPANNER_IS_MANAGED" => false
        }
      ]

      index_columns_result = [
        {
          "TABLE_CATALOG" => "",
          "TABLE_SCHEMA" => "",
          "TABLE_NAME" => "users",
          "INDEX_NAME" => "index_users_on_address_id",
          "INDEX_TYPE" => "INDEX",
          "COLUMN_NAME" => "address_id",
          "ORDINAL_POSITION" => 1,
          "COLUMN_ORDERING" => "ASC",
          "IS_NULLABLE" => "YES",
          "SPANNER_TYPE" => "INT64"
        }
      ]

      set_mocked_result index_columns_result
      set_mocked_result indexes_result

      column = new_table_column table_name: "users", column_name: "address_id"
      column.drop
      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.index_columns WHERE table_name='users'",
        "SELECT * FROM information_schema.indexes WHERE table_name='users'",
        "DROP INDEX index_users_on_address_id",
        "ALTER TABLE users DROP COLUMN address_id"
      )
    end
  end

  describe "#change" do
    it "set allow commit timestamp" do
      column = new_table_column table_name: "users", column_name: "created_at", type: "TIMESTAMP"
      column.allow_commit_timestamp.must_be :nil?

      column.allow_commit_timestamp = true
      column.change :options

      assert_sql_equal(
        last_executed_sql,
        "ALTER TABLE users ALTER COLUMN created_at SET OPTIONS (allow_commit_timestamp=true)"
      )

      column.allow_commit_timestamp = false
      column.change :options

      assert_sql_equal(
        last_executed_sql,
        "ALTER TABLE users ALTER COLUMN created_at SET OPTIONS (allow_commit_timestamp=null)"
      )
    end

    it "change column type" do
      column = new_table_column table_name: "users", column_name: "height", type: "FLOAT64"
      column.change

      assert_sql_equal(
        last_executed_sql,
        "ALTER TABLE users ALTER COLUMN height FLOAT64"
      )
    end

    it "change column to not null" do
      column = new_table_column(
        table_name: "users", column_name: "height", type: "FLOAT64", nullable: false
      )
      column.change

      assert_sql_equal(
        last_executed_sql,
        "ALTER TABLE users ALTER COLUMN height FLOAT64 NOT NULL"
      )
    end
  end

  describe "#reference_index" do
    it "set reference index" do
      column = new_table_column(table_name: "users", column_name: "username", type: "STRING")
      column.reference_index = "index_username_on_username"

      index = column.reference_index
      index.must_be_instance_of SpannerActiverecord::Index
      index.table.must_equal "users"
      index.name.must_equal "index_username_on_username"
      index.columns.length.must_equal 1
      index_column = index.columns.first
      index_column.table_name.must_equal "users"
      index_column.index_name.must_equal "index_username_on_username"
      index_column.name.must_equal "username"
    end
  end
end