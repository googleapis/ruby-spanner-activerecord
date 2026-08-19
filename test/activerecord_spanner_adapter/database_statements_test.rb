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
end
