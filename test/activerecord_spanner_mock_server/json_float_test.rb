# SPDX-License-Identifier: MIT

require_relative "base_spanner_mock_server_test"

module MockServerTests
  class JsonFloatTest < BaseSpannerMockServerTest
    def test_json_floats_in_dml_binds
      sql = "INSERT INTO `all_types` (`id`, `col_json`, `col_array_json`) VALUES (@p1, @p2, @p3)"
      @mock.put_statement_result sql, StatementResult.new(1)

      AllTypes.transaction do
        AllTypes.create! col_json: { amount: 0.0023529 },
                         col_array_json: [{ amount: 1.240425 }, nil], id: 1
      end

      request = @mock.requests.find do |candidate|
        candidate.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && candidate.sql == sql
      end
      assert request
      assert_equal :JSON, request.param_types["p2"].code
      assert_equal '{"amount":0.0023528999999999998}', request.params["p2"]
      assert_equal :JSON, request.param_types["p3"].array_element_type.code
      assert_equal '{"amount":1.240425}', request.params["p3"][0]
      assert_nil request.params["p3"][1]
    end

    def test_json_floats_in_buffered_mutations
      AllTypes.transaction isolation: :buffered_mutations do
        AllTypes.create! col_json: { amount: 0.0023529 },
                         col_array_json: [{ amount: 1.240425 }, nil], id: 1
      end

      request = @mock.requests.find { |candidate| candidate.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert request
      assert_equal 1, request.mutations.length
      mutation = request.mutations.first.insert
      values = mutation.columns.zip(mutation.values.first.values).to_h
      assert_equal '{"amount":0.0023528999999999998}', values.fetch("col_json").string_value
      assert_equal '{"amount":1.240425}', values.fetch("col_array_json").list_value.values[0].string_value
      assert_equal :null_value, values.fetch("col_array_json").list_value.values[1].kind
    end
  end
end
