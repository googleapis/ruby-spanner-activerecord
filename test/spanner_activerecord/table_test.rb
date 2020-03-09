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
    it "create a tables with default nullable and commit timestamp option" do
      table = new_table table_name: "stuffs"
      table.add_column "id", "INT64"
      table.add_column "int", "INT64"
      table.add_column "float", "FLOAT64"
      table.add_column "bool", "BOOL"
      table.add_column "string", "STRING"
      table.add_column "bytes", "BYTES"
      table.add_column "date", "DATE"
      table.add_column "timestamp", "TIMESTAMP"
      table.primary_keys = "id"

      table.create
      sql = [
        "CREATE TABLE stuffs(
          id INT64 NOT NULL,
          int INT64,
          float FLOAT64,
          bool BOOL,
          string STRING(MAX),
          bytes BYTES(MAX),
          date DATE,
          timestamp TIMESTAMP
        ) PRIMARY KEY(id)"
      ]
      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end

    it "create table with not nullable columns" do
      table = new_table table_name: "stuffs"
      table.add_column "id", "INT64"
      table.add_column "int", "INT64", nullable: false
      table.primary_keys = "id"

      table.create
      sql = [
        "CREATE TABLE stuffs(
          id INT64 NOT NULL,
          int INT64 NOT NULL
        ) PRIMARY KEY(id)"
      ]

      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end

    it "create table with allow commit timestamp options" do
      table = new_table table_name: "stuffs"
      table.add_column "id", "INT64"
      table.add_column "timestamp", "TIMESTAMP", allow_commit_timestamp: true
      table.add_column "created_at", "TIMESTAMP", nullable: false, allow_commit_timestamp: true
      table.primary_keys = "id"

      table.create
      sql = [
        "CREATE TABLE stuffs(
          id INT64 NOT NULL,
          timestamp TIMESTAMP OPTIONS (allow_commit_timestamp=true),
          created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp=true)
        ) PRIMARY KEY(id)"
      ]

      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end

    it "create table with string and bytes limit" do
      table = new_table table_name: "stuffs"
      table.add_column "id", "INT64"
      table.add_column "name", "STRING", limit: 255
      table.add_column "username", "STRING", limit: 255
      table.primary_keys = "id"

      table.create
      sql = [
        "CREATE TABLE stuffs(
          id INT64 NOT NULL,
          name STRING(255),
          username STRING(255)
        ) PRIMARY KEY(id)"
      ]

      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end

    it "allow multiple primary keys" do
      table = new_table table_name: "stuffs"
      table.add_column "domain_id", "INT64"
      table.add_column "username", "STRING"
      table.primary_keys = ["domain_id", "username"]

      table.create
      sql = [
        "CREATE TABLE stuffs(
          domain_id INT64 NOT NULL,
          username STRING(MAX) NOT NULL
        ) PRIMARY KEY(domain_id, username)"
      ]

      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end

    it "drop and create table" do
      table_name = "stuffs"
      index_name = "index_stuffs_on_username"

      table = new_table table_name: table_name
      table.add_column "id", "INT64"
      table.add_column "username", "STRING"
      table.primary_keys = "id"

      set_mocked_result [{"TABLE_NAME" => table_name}]
      set_mocked_result [{
        "TABLE_NAME" => table_name, "INDEX_NAME" => index_name, "COLUMN_NAME" => "user_id"
      }]
      set_mocked_result [{
        "TABLE_NAME" => table_name, "INDEX_NAME" => index_name, "COLUMN_NAME" => "user_id"
      }]
      set_mocked_result [{"TABLE_NAME" => table_name, "INDEX_NAME": index_name}]

      table.create drop_table: true
      sql = [
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='stuffs'",
        "SELECT * FROM information_schema.index_columns WHERE table_name='stuffs'",
        "SELECT * FROM information_schema.indexes WHERE table_name='stuffs'",
        "DROP INDEX index_stuffs_on_username",
        "DROP TABLE stuffs",
        "CREATE TABLE stuffs(
          id INT64 NOT NULL,
          username STRING(MAX)
        ) PRIMARY KEY(id)"
      ]

      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end

    it "create table with indexes" do
      table = new_table table_name: "users"
      table.add_column "id", "INT64"
      table.add_column "email", "STRING"
      table.add_column "firstname", "STRING"
      table.add_column "lastname", "STRING"
      table.primary_keys = ["id"]
      table.add_index "index_users_on_email", { email: :desc }, unique: true
      table.add_index "index_users_on_name", ["firstname", "lastname"]

      table.create
      sql = [
        "CREATE TABLE users(
          id INT64 NOT NULL,
          email STRING(MAX),
          firstname STRING(MAX),
          lastname STRING(MAX)
        ) PRIMARY KEY(id)",
        "CREATE UNIQUE INDEX index_users_on_email ON users (email DESC)",
        "CREATE INDEX index_users_on_name ON users (firstname, lastname)",
      ]

      assert_sql_equal(
        last_executed_sqls,
        sql
      )
    end
  end

  describe "#drop" do
    it "drop table without indexes" do
      table = new_table table_name: "stuffs"
      table.drop

      assert_sql_equal(
        last_executed_sqls,
        "DROP TABLE stuffs"
      )
    end

    it "drop table with indexes" do
      table_name = "stuffs"
      index_name = "index_stuffs_on_username"
      table = new_table table_name: table_name
      table.indexes = [new_index(table_name: table_name, index_name: index_name)]
      table.drop

      assert_sql_equal(
        last_executed_sqls,
        "DROP INDEX index_stuffs_on_username",
        "DROP TABLE stuffs",
      )
    end
  end

  describe "#alter" do
    it "add column to table" do
      table = new_table table_name: "users"
      table.add_column "email", "STRING", limit: 255, nullable: false
      table.add_column "address", "STRING"
      table.add_column "updated_at", "TIMESTAMP", allow_commit_timestamp: true
      table.alter

      assert_sql_equal(
        last_executed_sqls,
        "ALTER TABLE users ADD email STRING(255) NOT NULL",
        "ALTER TABLE users ADD address STRING(MAX)",
        "ALTER TABLE users ADD updated_at TIMESTAMP OPTIONS (allow_commit_timestamp=true)"
      )
    end

    it "set on delete cascase" do
      table = new_table table_name: "users", on_delete: "CASCADE"
      table.cascade_change

      assert_sql_equal(
        last_executed_sqls,
        "ALTER TABLE users SET ON DELETE CASCADE"
      )
    end

    it "set on delete no action" do
      table = new_table table_name: "users", on_delete: "NO ACTION"
      table.cascade_change

      assert_sql_equal(
        last_executed_sqls,
        "ALTER TABLE users SET ON DELETE NO ACTION"
      )
    end
  end
end