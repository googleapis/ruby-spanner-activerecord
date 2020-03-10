require "test_helper"

describe SpannerActiverecord::Index, :mock_spanner_activerecord  do
  let(:table_name) { "test-table" }
  let(:column_name) { "test-column" }
  let(:index_name) { "test-index"}

  describe "#new" do
    it "create a instance of index" do
      column = new_index_column(
        table_name: table_name, index_name:  index_name, column_name: column_name
      )
      index = SpannerActiverecord::Index.new(
        table_name, index_name, [column],
        unique: true, storing: ["test-storing"], connection: connection
      )

      index.table.must_equal table_name
      index.name.must_equal index_name
      index.columns.must_equal [column]
      index.unique.must_equal true
      index.storing.must_equal  ["test-storing"]
      index.primary?.must_equal false
    end
  end

  describe "#add_column" do
    it "add column in list of index columns" do
      index_name = "index_on_users_email"
      index = new_index(table_name: "users", index_name: index_name)

      index.add_column "email", order: "DESC"
      index.add_column "username"

      index.columns.length.must_equal 2
      columns = index.columns
      columns[0].name.must_equal "email"
      columns[0].desc?.must_equal true
      columns[1].name.must_equal "username"
      columns[1].desc?.must_equal false
    end

    it "update existing column" do
      index_name = "index_on_users_email"
      index = new_index(table_name: "users", index_name: index_name)

      index.add_column "email", order: "DESC"

      index.columns.length.must_equal 1
      index.columns[0].name.must_equal "email"
      index.columns[0].desc?.must_equal true

      index.add_column "email"
      index.columns.length.must_equal 1
      index.columns[0].name.must_equal "email"
      index.columns[0].desc?.must_equal false
    end
  end

  describe "#create" do
    it "create an index with default values" do
      index_name = "index_on_users_email_org_id"

      column1 = new_index_column(
        table_name: "users", index_name: "index_on_users_email_org_id", column_name: "email"
      )

      column2 = new_index_column(
        table_name: "users", index_name: "index_on_users_email_org_id", column_name: "org_id"
      )
      index = new_index  table_name: "users", index_name: index_name, columns: [column1, column2]

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE INDEX #{index_name} ON users (email, org_id)"
      )
    end

    it "create unique index" do
      index_name = "index_on_users_email"

      column = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column], unique: true
      )

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE UNIQUE INDEX #{index_name} ON users (email)"
      )
    end

    it "create unique null filtered index" do
      index_name = "index_on_users_email"

      column = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column],
        unique: true, null_filtered: true
      )

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE UNIQUE NULL_FILTERED INDEX #{index_name} ON users (email)"
      )
    end

    it "create index with storing" do
      index_name = "index_on_users_email"

      column1 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      column2 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "org_id"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column1, column2],
        storing: ["email"]
      )

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE INDEX #{index_name} ON users (email, org_id) STORING (email)"
      )
    end

    it "create index with interleave in" do
      index_name = "index_on_users_email"

      column1 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      column2 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "org_id"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column1, column2],
        interleve_in: "profiles"
      )

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE INDEX #{index_name} ON users (email, org_id), INTERLEAVE IN profiles"
      )
    end

    it "create index with all options set" do
      index_name = "index_on_users_email"

      column1 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      column2 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "org_id"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column1, column2],
        unique: true, null_filtered: true, storing: ["email, org_id"],
        interleve_in: "profiles"
      )

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE UNIQUE NULL_FILTERED INDEX #{index_name} ON users (email, org_id) STORING (email, org_id), INTERLEAVE IN profiles"
      )
    end

    it "create index with columns order" do
      index_name = "index_on_users_email"

      column1 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email", order:  "DESC"
      )
      column2 = new_index_column(
        table_name: "users", index_name: index_name, column_name: "org_id"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column1, column2]
      )

      index.create

      assert_sql_equal(
        last_executed_sqls,
        "CREATE INDEX #{index_name} ON users (email DESC, org_id)"
      )
    end
  end

  describe "#drop" do
    it "drop index" do
      index_name = "index_on_users_email"

      column = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column],
        unique: true, null_filtered: true
      )

      index.drop

      assert_sql_equal(
        last_executed_sqls,
        "DROP INDEX #{index_name}"
      )
    end
  end

  describe "#rename" do
    it "does not support rename" do
      index_name = "index_on_users_email"

      column = new_index_column(
        table_name: "users", index_name: index_name, column_name: "email"
      )
      index = new_index(
        table_name: "users", index_name: index_name, columns: [column]
      )

      proc{
        index.rename "new-name"
      }.must_raise SpannerActiverecord::NotSupportedError
    end
  end
end