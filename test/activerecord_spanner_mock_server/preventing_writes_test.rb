# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class ValidatedSinger < ActiveRecord::Base
    self.table_name = "singers"
    validates :first_name, presence: true
  end

  class PreventingWritesTest < BaseSpannerMockServerTest
    def test_reads_succeed_while_preventing_writes
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests.create_random_singers_result(1)

      hinted_sql = " @{USE_ADDITIONAL_PARALLELISM=true}SELECT  `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result hinted_sql, MockServerTests.create_random_singers_result(1)

      ActiveRecord::Base.while_preventing_writes do
        singer = Singer.find_by id: 1
        refute_nil singer

        hinted_singer = Singer.optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true}").find_by id: 1
        refute_nil hinted_singer

        ActiveRecord::Base.transaction isolation: :read_only do
          assert_equal singer.id, Singer.find_by(id: 1).id
        end

        ActiveRecord::Base.transaction isolation: { strong: true } do
          assert_equal singer.id, Singer.find_by(id: 1).id
        end

        ActiveRecord::Base.transaction do
          assert_equal singer.id, Singer.find_by(id: 1).id
        end

        with_sql = "WITH s AS (SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1) SELECT * FROM s"
        @mock.put_statement_result with_sql, MockServerTests.create_random_singers_result(1)
        assert_equal 1, Singer.connection.select_all(with_sql, "WITH", [1]).rows.length

        graph_sql = "GRAPH SingersGraph MATCH (s:Singer) RETURN s.id"
        @mock.put_statement_result graph_sql, MockServerTests.create_random_singers_result(1)
        assert_equal 1, Singer.connection.select_all(graph_sql).rows.length

        from_sql = "FROM `singers` |> SELECT `id`"
        @mock.put_statement_result from_sql, MockServerTests.create_random_singers_result(1)
        assert_equal 1, Singer.connection.select_all(from_sql).rows.length
      end
    end

    def test_buffered_mutation_writes_raise_read_only_error
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result select_sql, MockServerTests.create_random_singers_result(1)
      existing_singer = Singer.find_by id: 1
      @mock.requests.clear

      ActiveRecord::Base.while_preventing_writes do
        assert_raises ActiveRecord::ReadOnlyError do
          Singer.create! first_name: "Alice", last_name: "Smith"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.create first_name: "Alice", last_name: "Smith"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.insert!({ id: 10, first_name: "Alice", last_name: "Smith" })
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.insert_all! [{ id: 11, first_name: "Alice", last_name: "Smith" }]
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.upsert({ id: 12, first_name: "Alice", last_name: "Smith" })
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.upsert_all [{ id: 13, first_name: "Alice", last_name: "Smith" }]
        end

        assert_raises ActiveRecord::ReadOnlyError do
          existing_singer.update first_name: "Updated"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          existing_singer.destroy
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.delete_all
        end

        assert_raises ActiveRecord::ReadOnlyError do
          mutation = Google::Cloud::Spanner::V1::Mutation.new(
            delete: Google::Cloud::Spanner::V1::Mutation::Delete.new(
              table: "singers",
              key_set: { all: true }
            )
          )
          ActiveRecord::Base.connection.exec_mutation mutation
        end
      end

      assert_no_write_requests
    end

    def test_validation_failure_does_not_raise_read_only_error
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result select_sql, MockServerTests.create_random_singers_result(1)
      validated_singer = ValidatedSinger.find_by id: 1
      @mock.requests.clear

      ActiveRecord::Base.while_preventing_writes do
        refute validated_singer.update(first_name: nil)
        assert_includes validated_singer.errors[:first_name], "can't be blank"
      end

      assert_no_write_requests
    end

    def test_dml_and_statement_hinted_dml_raise_read_only_error
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result select_sql, MockServerTests.create_random_singers_result(1)
      existing_singer = Singer.find_by id: 1
      @mock.requests.clear

      ActiveRecord::Base.while_preventing_writes do
        assert_raises ActiveRecord::ReadOnlyError do
          TableWithIdentity.create! name: "Foo"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          TableWithIdentity.create name: "Foo"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          TableWithIdentity.transaction do
            TableWithIdentity.create! name: "Foo"
          end
        end

        assert_raises ActiveRecord::ReadOnlyError do
          existing_singer.update_columns first_name: "DirectDml"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          existing_singer.first_name = "SavedDml"
          existing_singer.save!
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.where(id: 1).update_all first_name: "Updated"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.update_all first_name: "UpdatedAll"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.where(id: 1).delete_all
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.insert({ id: 19, first_name: "Alice", last_name: "Smith" })
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer.insert_all [{ id: 20, first_name: "Alice", last_name: "Smith" }]
        end

        assert_raises ActiveRecord::ReadOnlyError do
          Singer
            .optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true}")
            .where(id: 1)
            .update_all first_name: "Hinted"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.connection.execute(
            " @{USE_ADDITIONAL_PARALLELISM=true}UPDATE `singers` SET `first_name` = 'Hinted' WHERE `id` = 1"
          )
        end

        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.transaction isolation: :pdml do
            Singer.where(id: 1).update_all first_name: "Pdml"
          end
        end

        original_isolation = ActiveRecord::Base.connection.isolation_level
        begin
          ActiveRecord::Base.connection.isolation_level = :pdml
          assert_raises ActiveRecord::ReadOnlyError do
            ActiveRecord::Base.transaction do
              Singer.where(id: 1).update_all first_name: "DefaultPdml"
            end
          end
        ensure
          ActiveRecord::Base.connection.isolation_level = original_isolation
        end
      end

      assert_no_write_requests
    end

    def test_truncate_and_ddl_raise_read_only_error
      ActiveRecord::Base.while_preventing_writes do
        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.connection.truncate "singers"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.connection.execute_ddl "CREATE TABLE `foo` (`id` INT64) PRIMARY KEY (`id`)"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.connection.execute "CREATE TABLE `foo` (`id` INT64) PRIMARY KEY (`id`)"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.connection.create_table :foo do |t|
            t.string :name
          end
        end
      end

      assert_no_write_requests
    end

    def test_batches_and_pre_buffered_mutations_raise_read_only_error
      connection = ActiveRecord::Base.connection

      ActiveRecord::Base.while_preventing_writes do
        assert_raises ActiveRecord::ReadOnlyError do
          connection.ddl_batch do
            connection.execute_ddl "CREATE TABLE `foo` (`id` INT64) PRIMARY KEY (`id`)"
          end
        end

        assert_raises ActiveRecord::ReadOnlyError do
          connection.dml_batch do
            connection.execute "UPDATE `singers` SET `first_name` = 'Batch' WHERE `id` = 1"
          end
        end

        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.dml_batch do
            connection.execute "UPDATE `singers` SET `first_name` = 'Batch' WHERE `id` = 1"
          end
        end

        assert_raises ActiveRecord::ReadOnlyError do
          connection.start_batch_ddl
        end

        assert_raises ActiveRecord::ReadOnlyError do
          connection.start_batch_dml
        end
      end

      # Starting a batch before while_preventing_writes should reject execution and run_batch inside it.
      connection.start_batch_dml
      begin
        ActiveRecord::Base.while_preventing_writes do
          assert_raises ActiveRecord::ReadOnlyError do
            connection.execute "UPDATE `singers` SET `first_name` = 'Batch' WHERE `id` = 1"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            connection.run_batch
          end
        end
      ensure
        connection.abort_batch
      end

      connection.start_batch_ddl
      begin
        ActiveRecord::Base.while_preventing_writes do
          assert_raises ActiveRecord::ReadOnlyError do
            connection.execute_ddl "CREATE TABLE `foo` (`id` INT64) PRIMARY KEY (`id`)"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            connection.run_batch
          end
        end
      ensure
        connection.abort_batch
      end

      # Pre-buffered mutations cannot be committed while preventing writes.
      connection.begin_isolated_db_transaction :buffered_mutations
      begin
        mutation = Google::Cloud::Spanner::V1::Mutation.new(
          delete: Google::Cloud::Spanner::V1::Mutation::Delete.new(
            table: "singers",
            key_set: { all: true }
          )
        )
        connection.exec_mutation mutation
        assert_raises ActiveRecord::ReadOnlyError do
          ActiveRecord::Base.while_preventing_writes do
            connection.commit_db_transaction
          end
        end
      ensure
        connection.rollback_db_transaction
      end

      assert_no_write_requests
    end

    def test_optimistic_locking_mutations_raise_read_only_error_without_version_check_query
      select_sql = "SELECT `versioned_singers`.* FROM `versioned_singers` WHERE `versioned_singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result select_sql, MockServerTests.create_random_singers_result(1, 2)
      versioned_singer = VersionedSinger.find 1
      @mock.requests.clear

      ActiveRecord::Base.while_preventing_writes do
        assert_raises ActiveRecord::ReadOnlyError do
          versioned_singer.update last_name: "Updated"
        end

        assert_raises ActiveRecord::ReadOnlyError do
          versioned_singer.destroy
        end
      end

      assert_equal 2, versioned_singer.lock_version
      sql_requests = @mock.requests.select { |request| request.is_a? Google::Cloud::Spanner::V1::ExecuteSqlRequest }
      assert_empty sql_requests
      assert_no_write_requests
    end

    def test_replica_connection_prevents_model_writes
      ActiveRecord::Base.establish_connection(
        adapter: "spanner",
        emulator_host: "localhost:#{@port}",
        project: "test-project",
        instance: "test-instance",
        database: "testdb",
        default_sequence_kind: "BIT_REVERSED_POSITIVE",
        replica: true
      )

      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests.create_random_singers_result(1)
      refute_nil Singer.find_by(id: 1)
      @mock.requests.clear

      assert_raises ActiveRecord::ReadOnlyError do
        Singer.create! first_name: "Replica", last_name: "Blocked"
      end

      assert_no_write_requests
    end

    private

    def assert_no_write_requests
      commit_requests = @mock.requests.select { |request| request.is_a? Google::Cloud::Spanner::V1::CommitRequest }
      assert_empty commit_requests

      batch_dml_requests = @mock.requests.select do |request|
        request.is_a? Google::Cloud::Spanner::V1::ExecuteBatchDmlRequest
      end
      assert_empty batch_dml_requests

      write_begin_requests = @mock.requests.select do |request|
        request.is_a?(Google::Cloud::Spanner::V1::BeginTransactionRequest) &&
          (request.options&.read_write || request.options&.partitioned_dml)
      end
      assert_empty write_begin_requests

      dml_requests = @mock.requests.select do |request|
        request.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) &&
          request.sql !~ /\A(?:SELECT|WITH|GRAPH|FROM)\b/i
      end
      assert_empty dml_requests
    end
  end
end
