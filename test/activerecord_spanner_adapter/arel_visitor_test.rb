# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class ArelVisitorTest < TestHelper::MockActiveRecordTest
  def setup
    super
    @adapter = ActiveRecord::ConnectionAdapters::SpannerAdapter.new(
      connection, nil, nil, { project: project_id, instance: instance_id, database: database_id }
    )
    @visitor = Arel::Visitors::Spanner.new @adapter
    @table = Arel::Table.new "users"
  end

  def test_compile_basic_select
    query = @table.project(Arel.star)
    sql = @visitor.compile query.ast
    assert_equal "SELECT * FROM `users`", sql
  end

  def test_compile_statement_hint
    query = @table.project(Arel.star)
    query.optimizer_hints "statement_hint: @{USE_ADDITIONAL_PARALLELISM=TRUE}"
    sql = @visitor.compile query.ast
    assert_equal " @{USE_ADDITIONAL_PARALLELISM=TRUE}SELECT  * FROM `users`", sql
  end

  def test_compile_table_hint
    query = @table.project(Arel.star)
    query.optimizer_hints "table_hint: users@{FORCE_INDEX=idx_users_name}"
    sql = @visitor.compile query.ast
    assert_equal "SELECT  * FROM `users`@{FORCE_INDEX=idx_users_name}", sql
  end

  def test_compile_table_hint_with_alias
    table_alias = @table.alias("u")
    query = Arel::SelectManager.new(table_alias).project(Arel.star)
    query.optimizer_hints "table_hint: users@{FORCE_INDEX=idx_users_name}"
    sql = @visitor.compile query.ast
    assert_equal "SELECT  * FROM `users`@{FORCE_INDEX=idx_users_name} `u`", sql
  end

  def test_compile_staleness_hints
    query = @table.project(Arel.star)
    query.optimizer_hints "max_staleness: 10.5"
    collector = Arel::Collectors::Composite.new(
      Arel::Collectors::SQLString.new,
      Arel::Collectors::Bind.new
    )
    _sql, binds = @visitor.compile(query.ast, collector)
    staleness_hint = binds.find { |bind| bind.is_a? Arel::Visitors::StalenessHint }
    refute_nil staleness_hint
    assert_equal({ max_staleness: 10.5 }, staleness_hint.value)
  end

  def test_compile_request_priority_hint
    query = @table.project(Arel.star)
    query.optimizer_hints "priority: PRIORITY_LOW"
    collector = Arel::Collectors::Composite.new(
      Arel::Collectors::SQLString.new,
      Arel::Collectors::Bind.new
    )
    _sql, binds = @visitor.compile(query.ast, collector)
    request_options = binds.find { |bind| bind.is_a? Google::Cloud::Spanner::V1::RequestOptions }
    refute_nil request_options
    assert_equal :PRIORITY_LOW, request_options.priority
  end

  def test_compile_comment_tags
    query = @table.project(Arel.star)
    query.comment "request_tag: select_users", "transaction_tag: tx_users"
    collector = Arel::Collectors::Composite.new(
      Arel::Collectors::SQLString.new,
      Arel::Collectors::Bind.new
    )
    _sql, binds = @visitor.compile(query.ast, collector)
    request_options = binds.find { |bind| bind.is_a? Google::Cloud::Spanner::V1::RequestOptions }
    refute_nil request_options
    assert_equal "select_users", request_options.request_tag
    assert_equal "tx_users", request_options.transaction_tag
  end

  def test_compile_pending_commit_timestamp_attribute
    time_type = ActiveRecord::Type::Spanner::Time.new
    attribute = ActiveModel::Attribute.from_user("created_at", :commit_timestamp, time_type)
    collector = Arel::Collectors::SQLString.new
    @visitor.send :visit_ActiveModel_Attribute, attribute, collector
    assert_equal "PENDING_COMMIT_TIMESTAMP()", collector.value
  end
end
