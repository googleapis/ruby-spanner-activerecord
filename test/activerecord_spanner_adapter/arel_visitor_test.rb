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
    query = @table.project Arel.star
    sql = @visitor.compile query.ast
    assert_equal "SELECT * FROM `users`", sql
  end

  def test_compile_statement_hint
    query = @table.project Arel.star
    query.optimizer_hints "statement_hint: @{USE_ADDITIONAL_PARALLELISM=TRUE}"
    sql = @visitor.compile query.ast
    assert_equal " @{USE_ADDITIONAL_PARALLELISM=TRUE}SELECT  * FROM `users`", sql
  end

  def test_compile_table_hint
    query = @table.project Arel.star
    query.optimizer_hints "table_hint: users@{FORCE_INDEX=idx_users_name}"
    sql = @visitor.compile query.ast
    assert_equal "SELECT  * FROM `users`@{FORCE_INDEX=idx_users_name}", sql
  end

  def test_compile_table_hint_with_alias
    table_alias = @table.alias "u"
    query = Arel::SelectManager.new(table_alias).project Arel.star
    query.optimizer_hints "table_hint: users@{FORCE_INDEX=idx_users_name}"
    sql = @visitor.compile query.ast
    assert_equal "SELECT  * FROM `users`@{FORCE_INDEX=idx_users_name} `u`", sql
  end

  def test_compile_staleness_hints
    query = @table.project Arel.star
    query.optimizer_hints "max_staleness: 10.5"
    collector = Arel::Collectors::Composite.new(
      Arel::Collectors::SQLString.new,
      Arel::Collectors::Bind.new
    )
    _sql, binds = @visitor.compile query.ast, collector
    staleness_hint = binds.find { |bind| bind.is_a? Arel::Visitors::StalenessHint }
    refute_nil staleness_hint
    assert_equal({ max_staleness: 10.5 }, staleness_hint.value)
  end

  def test_compile_request_priority_hint
    query = @table.project Arel.star
    query.optimizer_hints "priority: PRIORITY_LOW"
    collector = Arel::Collectors::Composite.new(
      Arel::Collectors::SQLString.new,
      Arel::Collectors::Bind.new
    )
    _sql, binds = @visitor.compile query.ast, collector
    request_options = binds.find { |bind| bind.is_a? Google::Cloud::Spanner::V1::RequestOptions }
    refute_nil request_options
    assert_equal :PRIORITY_LOW, request_options.priority
  end

  def test_compile_comment_tags
    query = @table.project Arel.star
    query.comment "request_tag: select_users", "transaction_tag: tx_users"
    collector = Arel::Collectors::Composite.new(
      Arel::Collectors::SQLString.new,
      Arel::Collectors::Bind.new
    )
    _sql, binds = @visitor.compile query.ast, collector
    request_options = binds.find { |bind| bind.is_a? Google::Cloud::Spanner::V1::RequestOptions }
    refute_nil request_options
    assert_equal "select_users", request_options.request_tag
    assert_equal "tx_users", request_options.transaction_tag
  end

  def test_compile_pending_commit_timestamp_attribute
    time_type = ActiveRecord::Type::Spanner::Time.new
    attribute = ActiveModel::Attribute.from_user "created_at", :commit_timestamp, time_type
    collector = Arel::Collectors::SQLString.new
    @visitor.send :visit_ActiveModel_Attribute, attribute, collector
    assert_equal "PENDING_COMMIT_TIMESTAMP()", collector.value
  end

  def test_collector_does_not_redefine_accessors_dynamically
    collector = Arel::Collectors::SQLString.new
    assert_respond_to collector, :hints
    assert_respond_to collector, :hints=
    assert_respond_to collector, :table_hints
    assert_respond_to collector, :table_hints=
    assert_respond_to collector, :join_hints
    assert_respond_to collector, :join_hints=

    # Ensure multiple compile calls run cleanly without re-defining methods
    query = @table.project Arel.star
    3.times { @visitor.compile query.ast }
    assert_equal "SELECT * FROM `users`", @visitor.compile(query.ast)
  end

  def test_compile_statement_hint_without_leading_space
    query = @table.project Arel.star
    query.optimizer_hints "statement_hint:@{USE_ADDITIONAL_PARALLELISM=TRUE}"
    sql = @visitor.compile query.ast
    assert_equal "@{USE_ADDITIONAL_PARALLELISM=TRUE}SELECT  * FROM `users`", sql
  end

  def test_compile_statement_hint_with_multiple_entries_and_quoted_values
    query = @table.project Arel.star
    query.optimizer_hints(
      "statement_hint: @{FORCE_INDEX=`idx@{1}`, JOIN_METHOD=HASH_JOIN, " \
      "spanner.optimizer_version=5, RATIO=-0.5, EXP=1e+5, TAG='a, b\\'} @{c', ESC=\"x\\\"y\", BK='a\\\\',\nMULTI=TRUE}"
    )
    sql = @visitor.compile query.ast
    expected = " @{FORCE_INDEX=`idx@{1}`, JOIN_METHOD=HASH_JOIN, spanner.optimizer_version=5, " \
               "RATIO=-0.5, EXP=1e+5, TAG='a, b\\'} @{c', ESC=\"x\\\"y\", BK='a\\\\',\nMULTI=TRUE}SELECT  * FROM `users`"
    assert_equal expected, sql
  end

  def test_compile_table_hint_with_quoted_hint_value_containing_at_brace
    query = @table.project Arel.star
    query.optimizer_hints "table_hint: users@{FORCE_INDEX=`idx@{1}`}"
    sql = @visitor.compile query.ast
    assert_equal "SELECT  * FROM `users`@{FORCE_INDEX=`idx@{1}`}", sql
  end

  def test_compile_table_hint_with_whitespace_and_schema
    query = @table.project Arel.star
    query.optimizer_hints "table_hint: users @{FORCE_INDEX=idx_users_name}"
    assert_equal "SELECT  * FROM `users`@{FORCE_INDEX=idx_users_name}", @visitor.compile(query.ast)

    schema_table = Arel::Table.new "my_schema.users"
    schema_query = schema_table.project Arel.star
    schema_query.optimizer_hints "table_hint: my_schema.users@{FORCE_INDEX=idx}"
    assert_equal "SELECT  * FROM `my_schema`.`users`@{FORCE_INDEX=idx}", @visitor.compile(schema_query.ast)
  end

  def test_rejects_invalid_statement_hints
    [
      "statement_hint:",
      "statement_hint:   ",
      "statement_hint: @{}",
      "statement_hint: @{   }",
      "statement_hint: @{A=1,}",
      "statement_hint: @{,A=1}",
      "statement_hint: @{A}",
      "statement_hint: @{A=}",
      "statement_hint: @{FÓO=1}",
      "statement_hint: @{A=--}",
      "statement_hint: @{A=--\n}",
      "statement_hint: @{A=1--2}",
      "statement_hint: @{A=..}",
      "statement_hint: @{A=1;SELECT}",
      "statement_hint: @{TAG='a\\'}",
      "statement_hint: @{TAG='a\\\r'}",
      "statement_hint: @{TAG='a\nb'}",
      "statement_hint: @{TAG=\"a\rb\"}",
      "statement_hint: @{A=1} @{B=2}",
      "statement_hint: @{USE_ADDITIONAL_PARALLELISM=TRUE} SELECT * FROM secrets UNION ALL ",
      "statement_hint: @{USE_ADDITIONAL_PARALLELISM=TRUE}\nSELECT 1",
      "statement_hint: SELECT 1; "
    ].each do |invalid_hint|
      query = @table.project Arel.star
      query.optimizer_hints invalid_hint

      error = assert_raises(ArgumentError, "Expected ArgumentError for #{invalid_hint.inspect}") do
        @visitor.compile query.ast
      end
      assert_match(/Invalid Spanner statement hint/, error.message)
    end
  end

  def test_rejects_invalid_table_hints
    [
      "table_hint:",
      "table_hint:   ",
      "table_hint: users",
      "table_hint: @{FORCE_INDEX=idx}",
      "table_hint: users@{}",
      "table_hint: users@{A=--}",
      "table_hint: users@{FORCE_INDEX=}",
      "table_hint: users@{FORCE_INDEX=idx",
      "table_hint: users@{FORCE_INDEX=idx,}",
      "table_hint: users@{A=1} @{B=2}",
      "table_hint: users@{FORCE_INDEX=idx} WHERE 1=1",
      "table_hint: users@{FORCE_INDEX=idx} WHERE 1=1 @{B=2}",
      "table_hint: users@{FORCE_INDEX=idx} WHERE 1=1 -- }"
    ].each do |invalid_hint|
      query = @table.project Arel.star
      query.optimizer_hints invalid_hint

      error = assert_raises(ArgumentError, "Expected ArgumentError for #{invalid_hint.inspect}") do
        @visitor.compile query.ast
      end
      assert_match(/Invalid Spanner table hint/, error.message)
    end
  end
end
