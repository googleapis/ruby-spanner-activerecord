# Copyright 2024 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"
require_relative "model_helper"

module MockServerTests
  # A table with a composite primary key where one of the key columns is NOT an
  # integer (STRING). Used to verify that the batch mutation path
  # (upsert_all / insert_all!) does not cast non-integer key columns with
  # BigInteger, which would corrupt the value (e.g. "abc" -> 0).
  class CompositeKeyProject < ActiveRecord::Base
    self.primary_key = [:project_id, :project_name]
  end
end

module MockServerTests
  class CompositePrimaryKeyMutationTest < BaseSpannerMockServerTest
    # Registers the column metadata for the composite key projects table.
    def register_composite_key_project_columns_result
      sql = MockServerTests.table_columns_sql "composite_key_projects"
      result_set = MockServerTests.create_columns_result_set

      row = ListValue.new
      row.values.push(
        Value.new(string_value: "project_id"),
        Value.new(string_value: "INT64"),
        Value.new(string_value: "NO"),
        Value.new(null_value: "NULL_VALUE"),
        Value.new(null_value: "NULL_VALUE"),
        Value.new(string_value: "1"),
        Value.new(string_value: "NO")
      )
      result_set.rows.push row

      row = ListValue.new
      row.values.push(
        Value.new(string_value: "project_name"),
        Value.new(string_value: "STRING(MAX)"),
        Value.new(string_value: "NO"),
        Value.new(null_value: "NULL_VALUE"),
        Value.new(null_value: "NULL_VALUE"),
        Value.new(string_value: "2"),
        Value.new(string_value: "NO")
      )
      result_set.rows.push row

      @mock.put_statement_result sql, StatementResult.new(result_set)
    end

    # Registers the primary key columns (project_id, project_name) for the table.
    def register_composite_key_project_key_columns_result
      sql = MockServerTests.primary_key_columns_sql "composite_key_projects", parent_keys: true

      result_set = StatementResult.new(ResultSet.new(
        metadata: ResultSetMetadata.new(
          row_type: StructType.new(
            fields: [
              Field.new(name: "INDEX_NAME", type: Type.new(code: TypeCode::STRING)),
              Field.new(name: "COLUMN_NAME", type: Type.new(code: TypeCode::STRING)),
              Field.new(name: "COLUMN_ORDERING", type: Type.new(code: TypeCode::INT64)),
              Field.new(name: "ORDINAL_POSITION", type: Type.new(code: TypeCode::INT64))
            ]
          )
        ),
        rows: [
          ListValue.new(values: [
            Value.new(string_value: "PRIMARY_KEY"),
            Value.new(string_value: "project_id"),
            Value.new(string_value: "1"),
            Value.new(string_value: "1")
          ]),
          ListValue.new(values: [
            Value.new(string_value: "PRIMARY_KEY"),
            Value.new(string_value: "project_name"),
            Value.new(string_value: "1"),
            Value.new(string_value: "2")
          ])
        ]
      ))
      @mock.put_statement_result sql, result_set
    end

    def setup_composite_key_project
      MockServerTests.register_commit_timestamps_result @mock, "composite_key_projects"
      register_composite_key_project_columns_result
      register_composite_key_project_key_columns_result
    end

    def test_upsert_all_does_not_cast_non_integer_composite_key_with_big_integer
      setup_composite_key_project

      MockServerTests::CompositeKeyProject.upsert_all [
        { project_id: 1, project_name: "alpha" },
        { project_id: 2, project_name: "beta" }
      ]

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 2, mutations.length

      first = mutations[0].insert_or_update
      assert_equal "composite_key_projects", first.table
      assert_equal ["project_id", "project_name"], first.columns.to_a
      # The STRING primary key column must survive unmangled. Before the fix this
      # was written as 0 (BigInteger.cast("alpha")) and the row got a random,
      # client-generated key instead of the provided one.
      assert_equal 1, first.values[0].values[0].string_value.to_i
      assert_equal "alpha", first.values[0].values[1].string_value

      second = mutations[1].insert_or_update
      assert_equal 2, second.values[0].values[0].string_value.to_i
      assert_equal "beta", second.values[0].values[1].string_value
    end

    def test_insert_all_bang_does_not_cast_non_integer_composite_key_with_big_integer
      setup_composite_key_project

      MockServerTests::CompositeKeyProject.insert_all! [
        { project_id: 3, project_name: "gamma" }
      ]

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length

      write = mutations[0].insert
      assert_equal "composite_key_projects", write.table
      assert_equal ["project_id", "project_name"], write.columns.to_a
      assert_equal 3, write.values[0].values[0].string_value.to_i
      assert_equal "gamma", write.values[0].values[1].string_value
    end
  end
end
