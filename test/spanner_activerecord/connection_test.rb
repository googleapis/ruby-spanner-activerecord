require "test_helper"

describe SpannerActiverecord::Connection, :mock_spanner_activerecord  do
  describe "#new" do
    it "create connection" do
      connection = SpannerActiverecord::Connection.new({
        project: project_id,
        instance: instance_id,
        database: database_id,
        credentials: credentials
      })

      connection.instance_id.must_equal instance_id
      connection.database_id.must_equal database_id
      connection.spanner.wont_be :nil?
      connection.session.wont_be :nil?
    end
  end

  describe "#create_database" do
    it "creates a database" do
      set_mocked_result "#{instance_id}/#{database_id}"
      database = connection.create_database
      database.must_equal "#{instance_id}/#{database_id}"
    end

    it "raise an error if issue in database creations" do
      set_mocked_result do
        raise "database already exists"
      end

      proc{
        connection.create_database
      }.must_raise Google::Cloud::Error
    end
  end

  describe "#database" do
    it "get a database" do
      database = connection.database
      database.wont_be :nil?
    end
  end

  describe "#active?" do
    it "checks connection is active" do
      connection.active?.must_equal true
    end

    it "returns false on error" do
      set_mocked_result { raise "database not available" }
      connection.active?.must_equal false
    end
  end

  describe "#disconnect!" do
    it "disconnect connection" do
      set_mocked_result true
      connection.disconnect!.must_equal true
    end
  end

  describe "#reset!" do
    it "reset connection" do
      set_mocked_result true
      connection.reset!.must_equal true
    end
  end

  describe "#execute_query" do
    it "query database" do
      set_mocked_result ["test-user"]
      result = connection.execute_query "SELECT * FROM users"
      result.rows.must_equal ["test-user"]
    end
  end

  describe "#execute_ddl" do
    it "execute ddl statements" do
      set_mocked_result true
      statement = "CREATE TABLE users ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
      result = connection.execute_ddl statement
      result.must_equal true

      last_executed_sql.must_sql_equal statement
    end

    it "raise an error if issue in executing sql statments " do
      set_mocked_result do
        raise "invalid sql statement"
      end

      proc{
        connection.execute_ddl "invalid sql"
      }.must_raise Google::Cloud::Error
    end
  end
end