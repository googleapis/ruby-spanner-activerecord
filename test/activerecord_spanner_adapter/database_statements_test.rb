# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class DatabaseStatementsTest < TestHelper::MockActiveRecordTest
  RequestOptions = Google::Cloud::Spanner::V1::RequestOptions

  def setup
    super
    @adapter = ActiveRecord::ConnectionAdapters::SpannerAdapter.new(
      connection, nil, nil, { project: project_id, instance: instance_id, database: database_id }
    )
  end

  def test_to_types_and_params_empty_binds
    types, params = @adapter.send :to_types_and_params, []
    assert_equal({}, types)
    assert_equal({}, params)
  end

  def test_to_types_and_params_with_attributes
    int_attr = ActiveModel::Attribute.from_user "id", 42, ActiveModel::Type::Integer.new
    str_attr = ActiveModel::Attribute.from_user "name", "Alice", ActiveModel::Type::String.new
    bool_attr = ActiveModel::Attribute.from_user "active", true, ActiveModel::Type::Boolean.new

    binds = [int_attr, str_attr, bool_attr]
    types, params = @adapter.send :to_types_and_params, binds

    assert_equal({ "p1" => :INT64, "p2" => :STRING, "p3" => :BOOL }, types)
    assert_equal({ "p1" => 42, "p2" => "Alice", "p3" => true }, params)
  end

  def test_to_types_and_params_with_symbols_and_booleans
    binds = [:production, true, false, 123]
    types, params = @adapter.send :to_types_and_params, binds

    assert_equal({ "p1" => :STRING, "p2" => :BOOL, "p3" => :BOOL, "p4" => :INT64 }, types)
    assert_equal({ "p1" => :production, "p2" => true, "p3" => false, "p4" => 123 }, params)
  end

  def test_to_types_and_params_preserves_frozen_keys_up_to_950
    binds = Array.new(955) { |i| ActiveModel::Attribute.from_user "col_#{i}", i, ActiveModel::Type::Integer.new }
    types, params = @adapter.send :to_types_and_params, binds

    assert_equal 955, types.size
    assert_equal 955, params.size
    assert_equal "p1", types.keys.first
    assert_equal "p950", types.keys[949]
    assert_equal "p955", types.keys.last
    assert_equal 0, params["p1"]
    assert_equal 949, params["p950"]
    assert_equal 954, params["p955"]
  end

  def test_to_types_and_to_params_compatibility_methods
    int_attr = ActiveModel::Attribute.from_user "id", 1, ActiveModel::Type::Integer.new
    types = @adapter.send :to_types, [int_attr]
    params = @adapter.send :to_params, [int_attr]

    assert_equal({ "p1" => :INT64 }, types)
    assert_equal({ "p1" => 1 }, params)
  end

  def test_append_request_tag_from_query_logs_with_prefix
    binds = []
    sql = "/*request_tag:true,app_users*/ SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_equal 1, binds.size
    assert_instance_of RequestOptions, binds.first
    assert_equal "app_users", binds.first.request_tag
  end

  def test_append_request_tag_from_query_logs_with_alternate_prefix
    binds = []
    sql = "/*_request_tag='true',custom_tag*/ SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_equal 1, binds.size
    assert_instance_of RequestOptions, binds.first
    assert_equal "custom_tag", binds.first.request_tag
  end

  def test_append_request_tag_does_not_duplicate_existing_options_object
    existing_options = RequestOptions.new request_tag: "initial_tag"
    binds = [existing_options]
    sql = "/*request_tag:true,second_tag*/ SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_equal 1, binds.size
    assert_same existing_options, binds.first
    assert_equal "initial_tag,second_tag", binds.first.request_tag
  end

  def test_append_request_tag_from_query_logs_with_third_prefix
    binds = []
    sql = "/*_request_tag:true,third_tag*/ SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_equal 1, binds.size
    assert_instance_of RequestOptions, binds.first
    assert_equal "third_tag", binds.first.request_tag
  end

  def test_append_request_tag_with_empty_initial_request_tag
    existing_options = RequestOptions.new request_tag: ""
    binds = [existing_options]
    sql = "/*request_tag:true,new_tag*/ SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_equal 1, binds.size
    assert_same existing_options, binds.first
    assert_equal "new_tag", binds.first.request_tag
  end

  def test_append_request_tag_with_unclosed_comment
    binds = []
    sql = "/*request_tag:true,unclosed_tag SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_empty binds
  end

  def test_append_request_tag_with_non_matching_comment
    binds = []
    sql = "/* some other comment */ SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_empty binds
  end

  def test_append_request_tag_ignores_unmatched_sql
    binds = []
    sql = "SELECT * FROM users"
    @adapter.send :append_request_tag_from_query_logs, sql, binds

    assert_empty binds
  end

  def test_write_query_allows_read_statements_and_hinted_reads
    [
      "SELECT * FROM users",
      " @{USE_ADDITIONAL_PARALLELISM=true}SELECT * FROM users",
      "@{OPTIMIZER_STATISTICS_PACKAGE='a}b'} SELECT * FROM users",
      "/* comment */ -- line\n # hash comment\n @{FORCE_INDEX=idx} (SELECT 1)",
      "# hash comment\nSELECT * FROM users",
      "SELECT 1 /* \xFF */".dup.force_encoding(Encoding::UTF_8),
      "WITH cte AS (SELECT 1) SELECT * FROM cte",
      "GRAPH FinGraph MATCH (n) RETURN n.id",
      "FROM Singers |> SELECT Id",
      "SHOW TABLES",
      "EXPLAIN SELECT 1",
      "BEGIN",
      "COMMIT",
      "ROLLBACK"
    ].each do |sql|
      refute @adapter.write_query?(sql), "Expected write_query? to be false for: #{sql}"
    end
  end

  def test_write_query_detects_dml_ddl_hinted_writes_and_unknown_writes
    [
      "INSERT INTO users (id) VALUES (1)",
      "UPDATE users SET name = 'a'",
      "DELETE FROM users WHERE id = 1",
      "# hash comment\nUPDATE users SET name = 'a'",
      " @{USE_ADDITIONAL_PARALLELISM=true}UPDATE users SET name = 'a'",
      "@{OPTIMIZER_STATISTICS_PACKAGE='a}b'} DELETE FROM users WHERE id = 1",
      "/* tag */ @{a=1} (INSERT INTO users (id) VALUES (1))",
      "UPDATE users SET name = '\xFF'".dup.force_encoding(Encoding::UTF_8),
      "CREATE TABLE users (id INT64) PRIMARY KEY (id)",
      "ALTER TABLE users ADD COLUMN name STRING(MAX)",
      "DROP TABLE users",
      "RENAME TABLE users TO people",
      "GRANT SELECT ON TABLE users TO ROLE reader",
      "REVOKE SELECT ON TABLE users FROM ROLE reader",
      "ANALYZE",
      "TRUNCATE TABLE users",
      "UPDATE_CUSTOM SELECT 1"
    ].each do |sql|
      assert @adapter.write_query?(sql), "Expected write_query? to be true for: #{sql}"
    end
  end

  def test_sql_statement_type_with_statement_hints_and_ddl_keywords
    assert_equal :dql, @adapter.send(:sql_statement_type, " @{USE_ADDITIONAL_PARALLELISM=true}SELECT * FROM users")
    assert_equal :dql, @adapter.send(:sql_statement_type, "# hash comment\nSELECT * FROM users")
    assert_equal :dml, @adapter.send(:sql_statement_type, " @{USE_ADDITIONAL_PARALLELISM=true}UPDATE users SET name = 'a'")
    assert_equal :dml, @adapter.send(:sql_statement_type, "# hash comment\nUPDATE users SET name = 'a'")
    assert_equal :dml, @adapter.send(:sql_statement_type, "@{a='}'} DELETE FROM users WHERE id = 1")
    assert_equal :dml, @adapter.send(:sql_statement_type, "/* c */ @{a=1} INSERT INTO users (id) VALUES (1)")
    assert_equal :dml, @adapter.send(:sql_statement_type, "UPDATE users SET name = '\xFF'".dup.force_encoding(Encoding::UTF_8))
    assert_equal :ddl, @adapter.send(:sql_statement_type, "CREATE TABLE users (id INT64) PRIMARY KEY (id)")
    assert_equal :ddl, @adapter.send(:sql_statement_type, "RENAME TABLE users TO people")
    assert_equal :ddl, @adapter.send(:sql_statement_type, "GRANT SELECT ON TABLE users TO ROLE reader")
    assert_equal :ddl, @adapter.send(:sql_statement_type, "REVOKE SELECT ON TABLE users FROM ROLE reader")
    assert_equal :ddl, @adapter.send(:sql_statement_type, "ANALYZE")
  end

  def test_internal_execute_raises_read_only_error_when_preventing_writes
    @adapter.stub :preventing_writes?, true do
      [
        "UPDATE users SET name = 'a' WHERE id = 1",
        "/*request_tag:true,write_tag*/ @{USE_ADDITIONAL_PARALLELISM=true}UPDATE users SET name = 'a' WHERE id = 1",
        "CREATE TABLE users (id INT64) PRIMARY KEY (id)"
      ].each do |sql|
        binds = []
        error = assert_raises ActiveRecord::ReadOnlyError do
          @adapter.send :internal_execute, sql, "SQL", binds
        end
        assert_match(/Write query attempted while in readonly mode/, error.message)
        assert_empty binds
      end
    end
  end

  def test_replica_config_enables_preventing_writes
    replica_adapter = ActiveRecord::ConnectionAdapters::SpannerAdapter.new(
      connection, nil, nil, { project: project_id, instance: instance_id, database: database_id, replica: true }
    )
    assert replica_adapter.preventing_writes?
    error = assert_raises ActiveRecord::ReadOnlyError do
      replica_adapter.execute "UPDATE users SET name = 'a' WHERE id = 1"
    end
    assert_match(/Write query attempted while in readonly mode/, error.message)
  end
end
