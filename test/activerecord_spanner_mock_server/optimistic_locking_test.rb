# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class OptimisticLockingTest < BaseSpannerMockServerTest
    def test_versioned_update_using_dml
      version = 2
      register_versioned_singer_find_by_id_result version
      update_sql = register_update_versioned_singer_result 1

      singer = VersionedSinger.find 1
      VersionedSinger.transaction do
        singer.update last_name: "Rakefield"
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }.first
      assert request
      # Ensure that the update statement sets the new lock version to 3 and verifies that the current value is 2.
      assert_equal "3", request.params["p2"]
      assert_equal "2", request.params["p4"]
    end

    def test_versioned_update_using_dml_stale_object
      version = 3
      register_versioned_singer_find_by_id_result version
      # The update statement will return row count 0, which indicates that the object is stale.
      update_sql = register_update_versioned_singer_result 0

      singer = VersionedSinger.find 1
      VersionedSinger.transaction do
        assert_raises ActiveRecord::StaleObjectError do
          singer.update last_name: "Rakefield"
        end
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }.first
      assert request
      assert_equal "4", request.params["p2"]
      assert_equal "3", request.params["p4"]
    end

    def test_versioned_delete_using_dml
      version = 2
      register_versioned_singer_find_by_id_result version
      delete_sql = register_delete_versioned_singer_result 1

      singer = VersionedSinger.find 1
      VersionedSinger.transaction do
        singer.destroy
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == delete_sql }.first
      assert request
      assert_equal "2", request.params["p2"]
    end

    def test_versioned_delete_using_dml_stale_object
      version = 3
      register_versioned_singer_find_by_id_result version
      delete_sql = register_delete_versioned_singer_result 0

      singer = VersionedSinger.find 1
      VersionedSinger.transaction do
        assert_raises ActiveRecord::StaleObjectError do
          singer.destroy
        end
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == delete_sql }.first
      assert request
      assert_equal "3", request.params["p2"]
    end

    def test_versioned_update_using_implicit_transaction
      version = 2
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result true

      singer = VersionedSinger.find 1
      singer.update last_name: "Rakefield"

      # When an update is done using mutations, the version check is executed using a SELECT statement inside the transaction.
      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      assert select_request
      assert commit_request

      assert_equal version.to_s, select_request.params["lock_version"]
      assert select_request.transaction&.begin&.read_write

      mutation = commit_request.mutations[0]
      col_index = -1
      assert_equal "id", mutation.update.columns[col_index += 1]
      assert_equal "last_name", mutation.update.columns[col_index += 1]
      assert_equal "lock_version", mutation.update.columns[col_index += 1]

      value_index = -1
      assert_equal singer.id.to_s, mutation.update.values[0][value_index += 1]
      assert_equal "Rakefield", mutation.update.values[0][value_index += 1]
      assert_equal (version + 1).to_s, mutation.update.values[0][value_index += 1]
    end

    def test_versioned_update_using_implicit_transaction_stale_object
      version = 3
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result false

      singer = VersionedSinger.find 1
      assert_raises ActiveRecord::StaleObjectError do
        singer.update last_name: "Rakefield"
      end

      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      # The version check should be executed and then the transaction should stop without a commit, as the version check
      # failed.
      assert select_request
      assert_equal version.to_s, select_request.params["lock_version"]
      refute commit_request
    end

    def test_versioned_delete_using_implicit_transaction
      version = 2
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result true

      singer = VersionedSinger.find 1
      singer.destroy

      # When a delete is done using mutations, the version check is executed using a SELECT statement inside the transaction.
      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      assert select_request
      assert commit_request

      assert_equal version.to_s, select_request.params["lock_version"]
      assert select_request.transaction&.begin&.read_write

      mutation = commit_request.mutations[0]
      assert_equal :delete, mutation.operation
      assert_equal "versioned_singers", mutation.delete.table
      assert_equal 1, mutation.delete.key_set.keys.length
      assert_equal singer.id, mutation.delete.key_set.keys[0][0].to_i
    end

    def test_versioned_delete_using_implicit_transaction_stale_object
      version = 3
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result false

      singer = VersionedSinger.find 1
      assert_raises ActiveRecord::StaleObjectError do
        singer.destroy
      end

      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first

      assert select_request
      assert_equal version.to_s, select_request.params["lock_version"]
      refute commit_request
    end

    def test_versioned_update_using_explicit_transaction_with_mutations
      version = 2
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result true

      singer = VersionedSinger.find 1
      VersionedSinger.transaction isolation: :buffered_mutations do
        VersionedSinger.create first_name: "New", last_name: "Singer"
        singer.update last_name: "Rakefield"
      end

      # When an update is done using mutations, the version check is executed using a SELECT statement inside the transaction.
      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      assert_empty begin_requests
      assert select_request
      assert commit_request

      assert_equal version.to_s, select_request.params["lock_version"]
      assert select_request.transaction&.begin&.read_write
      assert_equal 2, commit_request.mutations.length

      insert = commit_request.mutations[0]
      update = commit_request.mutations[1]
      assert_equal :insert, insert.operation
      assert_equal :update, update.operation
    end

    def test_versioned_update_using_explicit_transaction_with_mutations_stale_object
      version = 3
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result false

      singer = VersionedSinger.find 1
      VersionedSinger.transaction isolation: :buffered_mutations do
        VersionedSinger.create first_name: "New", last_name: "Singer"
        assert_raises ActiveRecord::StaleObjectError do
          singer.update last_name: "Rakefield"
        end
      end

      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      assert select_request
      assert_equal version.to_s, select_request.params["lock_version"]

      # The insert should be executed.
      assert commit_request
      assert_equal 1, commit_request.mutations.length

      insert = commit_request.mutations[0]
      assert_equal :insert, insert.operation
    end

    def test_versioned_delete_using_explicit_transaction_with_mutations
      version = 2
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result true

      singer = VersionedSinger.find 1
      VersionedSinger.transaction isolation: :buffered_mutations do
        VersionedSinger.create first_name: "New", last_name: "Singer"
        singer.destroy
      end

      # When a delete is done using mutations, the version check is executed using a SELECT statement inside the transaction.
      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      assert select_request
      assert commit_request

      assert_equal version.to_s, select_request.params["lock_version"]
      assert select_request.transaction&.begin&.read_write

      insert = commit_request.mutations[0]
      delete = commit_request.mutations[1]
      assert_equal :insert, insert.operation
      assert_equal :delete, delete.operation
    end

    def test_versioned_delete_using_explicit_transaction_with_mutations_stale_object
      version = 3
      register_versioned_singer_find_by_id_result version
      select_sql = register_version_check_result false

      singer = VersionedSinger.find 1
      VersionedSinger.transaction isolation: :buffered_mutations do
        VersionedSinger.create first_name: "New", last_name: "Singer"
        assert_raises ActiveRecord::StaleObjectError do
          singer.destroy
        end
      end

      select_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first

      assert select_request
      assert_equal version.to_s, select_request.params["lock_version"]

      # The insert should be executed.
      assert commit_request
      assert_equal 1, commit_request.mutations.length

      insert = commit_request.mutations[0]
      assert_equal :insert, insert.operation
    end

    def register_insert_versioned_singer_result
      sql = "INSERT INTO `versioned_singers` (`first_name`, `last_name`, `lock_version`, `id`) " \
            "VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result sql, StatementResult.new(1)
      sql
    end

    def register_update_versioned_singer_result update_count
      sql = "UPDATE `versioned_singers` SET `last_name` = @p1, `lock_version` = @p2 " \
            "WHERE `versioned_singers`.`id` = @p3 AND `versioned_singers`.`lock_version` = @p4"
      @mock.put_statement_result sql, StatementResult.new(update_count)
      sql
    end

    def register_delete_versioned_singer_result update_count
      sql = "DELETE FROM `versioned_singers` " \
            "WHERE `versioned_singers`.`id` = @p1 AND `versioned_singers`.`lock_version` = @p2"
      @mock.put_statement_result sql, StatementResult.new(update_count)
      sql
    end

    def register_versioned_singer_find_by_id_result lock_version
      sql = "SELECT `versioned_singers`.* FROM `versioned_singers` WHERE `versioned_singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1, lock_version)
      sql
    end

    def register_version_check_result result
      sql = "SELECT 1 FROM `versioned_singers` WHERE `id` = @id AND `lock_version` = @lock_version"
      col = Google::Cloud::Spanner::V1::StructType::Field.new name: "", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)

      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push col
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

      if result
        row = Google::Protobuf::ListValue.new
        row.values.push(Google::Protobuf::Value.new(string_value: "1"))
        result_set.rows.push row
      end

      @mock.put_statement_result sql, StatementResult.new(result_set)
      sql
    end
  end
end
