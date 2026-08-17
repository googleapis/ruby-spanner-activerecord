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
