require "test_helper"

class SpannerConnectionTest < TestHelper::MockActiveRecordTest
  def test_create_connection
    connection = ActiveRecordSpannerAdapter::Connection.new({
      project: project_id,
      instance: instance_id,
      database: database_id,
      credentials: credentials
    })

    assert_equal connection.instance_id, instance_id
    assert_equal connection.database_id, database_id
    refute_nil connection.spanner
    refute_nil connection.session
  end

  def test_create_database
    set_mocked_result "#{instance_id}/#{database_id}"
    database = connection.create_database
    assert_equal database, "#{instance_id}/#{database_id}"
  end

  def test_raise_an_error_if_issue_in_connection
    set_mocked_result do
      raise "database already exists"
    end

    assert_raises(Google::Cloud::Error) {
      connection.create_database
    }
  end

  def test_get_database
    database = connection.database
    refute_nil database
  end

  def test_connection_is_active
    assert_equal connection.active?, true
  end

  def test_connection_not_active_on_error
    set_mocked_result { raise "database not available" }
    assert_equal connection.active?, false
  end

  def test_disconnect_connection
    set_mocked_result true
    assert_equal connection.disconnect!, true
  end

  def test_reset_connecton
    set_mocked_result true
    assert_equal connection.reset!, true
  end

  def test_execute_query
    set_mocked_result ["test-user"]
    result = connection.execute_query "SELECT * FROM users"
    assert_equal result.rows, ["test-user"]
  end

  def test_execute_ddl_statements
    set_mocked_result true
    statement = "CREATE TABLE users ( id STRING(36) NOT NULL ) PRIMARY KEY (id)"
    result = connection.execute_ddl statement
    assert_equal result, true

    assert_sql_equal last_executed_sql, statement
  end

  def test_raise_error_on_executing_ddl_statement
    set_mocked_result do
      raise "invalid sql statement"
    end

    assert_raises(Google::Cloud::Error) {
      connection.execute_ddl "invalid sql"
    }
  end
end
