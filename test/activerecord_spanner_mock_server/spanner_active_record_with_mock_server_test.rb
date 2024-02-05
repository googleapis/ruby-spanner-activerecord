# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "sqlite3"
require_relative "./base_spanner_mock_server_test"
require_relative "models/other_adapter"

module MockServerTests
  CommitRequest = Google::Cloud::Spanner::V1::CommitRequest
  ExecuteSqlRequest = Google::Cloud::Spanner::V1::ExecuteSqlRequest

  class SpannerActiveRecordMockServerTest < BaseSpannerMockServerTest
    VERSION_7_1_0 = Gem::Version.create('7.1.0')

    def test_insert
      singer = { first_name: "Alice", last_name: "Ecila" }

      assert_raises(NotImplementedError) { Singer.insert(singer) }
    end

    def test_insert_other_adapter
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: ":memory:",
      )
      ActiveRecord::Base.logger = nil
      ActiveRecord::Schema.define(version: 1) do
        create_table :systems do |t|
          t.string  :name
        end

        create_table :plans do |t|
          t.string  :name
        end

        # simulate a join table with no primary key
        create_table :projects, id: false do |t|
          t.integer  :plan_id
          t.integer  :system_id
          t.index [:plan_id, :system_id], unique: true
        end
      end

      system = System.create(name: "Baroque")
      plan = Plan.create(name: "Music")
      # This would previously fail, as the table has no primary key.
      Project.create(plan_id: plan.id, system_id: system.id)
    end

    def test_insert!
      singer = { first_name: "Alice", last_name: "Ecila" }
      singer = Singer.insert! singer
      id = singer[0]["id"]
      id = id.value if id.respond_to?(:value)

      commit_requests = @mock.requests.select { |req| req.is_a?(CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :insert, mutation.operation
      assert_equal "singers", mutation.insert.table

      assert_equal 1, mutation.insert.values.length
      assert_equal 3, mutation.insert.values[0].length
      assert_equal "Alice", mutation.insert.values[0][0]
      assert_equal "Ecila", mutation.insert.values[0][1]
      assert_equal id, mutation.insert.values[0][2].to_i

      assert_equal 3, mutation.insert.columns.length
      assert_equal "first_name", mutation.insert.columns[0]
      assert_equal "last_name", mutation.insert.columns[1]
      assert_equal "id", mutation.insert.columns[2]
    end

    def test_upsert
      singer = { first_name: "Alice", last_name: "Ecila" }
      singer = Singer.upsert singer
      id = singer[0]["id"]
      id = id.value if id.respond_to?(:value)

      commit_requests = @mock.requests.select { |req| req.is_a?(CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :insert_or_update, mutation.operation
      assert_equal "singers", mutation.insert_or_update.table

      assert_equal 1, mutation.insert_or_update.values.length
      assert_equal 3, mutation.insert_or_update.values[0].length
      assert_equal "Alice", mutation.insert_or_update.values[0][0]
      assert_equal "Ecila", mutation.insert_or_update.values[0][1]
      assert_equal id, mutation.insert_or_update.values[0][2].to_i

      assert_equal 3, mutation.insert_or_update.columns.length
      assert_equal "first_name", mutation.insert_or_update.columns[0]
      assert_equal "last_name", mutation.insert_or_update.columns[1]
      assert_equal "id", mutation.insert_or_update.columns[2]
    end

    def test_selects_all_singers_without_transaction
      sql = "SELECT `singers`.* FROM `singers`"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(4)
      Singer.all.each do |singer|
        refute_nil singer.id, "singer.id should not be nil"
        refute_nil singer.first_name, "singer.first_name should not be nil"
        refute_nil singer.last_name, "singer.last_name should not be nil"
      end
      # None of the requests should use a (read-only) transaction.
      select_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::ExecuteSqlRequest }
      select_requests.each do |request|
        assert_nil request.transaction
      end
      # Executing a simple query should not initiate any transactions.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
    end

    def test_selects_one_singer_without_transaction
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      singer = Singer.find_by id: 1

      refute_nil singer
      refute_nil singer.first_name
      refute_nil singer.last_name
      # None of the requests should use a (read-only) transaction.
      select_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::ExecuteSqlRequest }
      select_requests.each do |request|
        assert_nil request.transaction
      end
      # Executing a simple query should not initiate any transactions.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests

      # Check the encoded parameters.
      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      select_requests.each do |request|
        assert_equal "1", request.params["p2"]
        assert_equal "1", request.params["p1"]
        assert_equal :INT64, request.param_types["p2"].code
        assert_equal :INT64, request.param_types["p1"].code
      end
    end

    def test_selects_singers_with_condition
      # This query does not use query parameters because the where clause is specified as a string.
      # ActiveRecord sees that as a SQL fragment that will disable the usage of prepared statements.
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`last_name` LIKE 'A%'"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(2)
      Singer.where(Singer.arel_table[:last_name].matches("A%")).each do |singer|
        refute_nil singer.id, "singer.id should not be nil"
        refute_nil singer.first_name, "singer.first_name should not be nil"
        refute_nil singer.last_name, "singer.last_name should not be nil"
      end
      # None of the requests should use a (read-only) transaction.
      select_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::ExecuteSqlRequest }
      select_requests.each do |request|
        assert_nil request.transaction
      end
      # Executing a simple query should not initiate any transactions.
      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
    end

    def test_update_one_singer_should_use_transaction
      # Preferably, this use case should use mutations instead of DML, as single updates
      # using DML are a lot slower than using mutations. Mutations can however not be
      # read back during a transaction (no read-your-writes), but that is not needed in
      # this case as the application is not managing the transaction itself.
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result select_sql, MockServerTests::create_random_singers_result(1)

      singer = Singer.find_by id: 1

      update_sql = "UPDATE `singers` SET `first_name` = @p1 WHERE `singers`.`id` = @p2"
      @mock.put_statement_result update_sql, StatementResult.new(1)

      singer.first_name = 'Dave'
      singer.save!

      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      # Check the encoded parameters.
      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }
      select_requests.each do |request|
        assert request.transaction&.begin&.read_write
        assert_equal "Dave", request.params["p1"]
        assert_equal singer.id.to_s, request.params["p2"]
        assert_equal :STRING, request.param_types["p1"].code
        assert_equal :INT64, request.param_types["p2"].code
      end
    end

    def test_update_two_singers_should_use_transaction
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` BETWEEN @p1 AND @p2"
      @mock.put_statement_result select_sql, MockServerTests::create_random_singers_result(2)

      update_sql = "UPDATE `singers` SET `first_name` = @p1 WHERE `singers`.`id` = @p2"
      ActiveRecord::Base.transaction do
        singers = Singer.where id: 1..2
        @mock.put_statement_result update_sql, StatementResult.new(1)

        singers[0].update! first_name: "Name1"
        singers[1].update! first_name: "Name2"
      end

      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_empty begin_transaction_requests
      # All of the SQL requests should use a transaction.
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && (req.sql.start_with?("SELECT `singers`.*") || req.sql.start_with?("UPDATE")) }
      assert_equal 3, sql_requests.length
      sql_requests.each_with_index do |request, index|
        refute_nil request.transaction
        if index > 0
          @id ||= request.transaction.id
          assert_equal @id, request.transaction.id
        else
          assert request.transaction.begin&.read_write
        end
      end

      update_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }
      assert_equal 2, update_requests.length

      singers = Singer.where id: 1..2
      update_requests.each_with_index do |request, index|
        assert_equal "Name#{index+1}", request.params["p1"]
        assert_equal "#{singers[index].id}", request.params["p2"]
        assert_equal :STRING, request.param_types["p1"].code
        assert_equal :INT64, request.param_types["p2"].code
      end
    end

    def test_save_with_sequence
      insert_sql = "INSERT INTO `table_with_sequence` (`name`) VALUES (@p1) THEN RETURN `id`"
      @mock.put_statement_result insert_sql, MockServerTests::create_id_returning_result_set(1, 1)

      record = TableWithSequence.transaction do
        TableWithSequence.create(name: "Foo")
      end
      assert_equal 1, record.id
    end

    def test_save_with_sequence_without_transaction
      insert_sql = "INSERT INTO `table_with_sequence` (`name`) VALUES (@p1) THEN RETURN `id`"
      @mock.put_statement_result insert_sql, MockServerTests::create_id_returning_result_set(1, 1)

      record = TableWithSequence.create(name: "Foo")
      assert_equal 1, record.id
    end

    def test_save_with_sequence_and_mutations
      err = assert_raises ActiveRecord::StatementInvalid do
        TableWithSequence.transaction isolation: :buffered_mutations do
          TableWithSequence.create(name: "Foo")
        end
      end
      assert_equal "Mutations cannot be used to create records that use a sequence to generate the primary key. MockServerTests::TableWithSequence uses test_sequence.", err.message
    end

    def test_after_save
      singer = Singer.create(first_name: "Dave", last_name: "Allison")

      assert singer.id
      assert_equal "Dave Allison", singer.full_name
    end

    def test_after_save_buffered_mutations
      singer = Singer.transaction isolation: :buffered_mutations do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      assert singer.id
      assert_equal "Dave Allison", singer.full_name
    end

    def test_after_save_transaction
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `id`) VALUES (@p1, @p2, @p3)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      singer = Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison")
      end

      assert singer.id
      assert_equal "Dave Allison", singer.full_name
    end

    def test_create_singer_with_last_performance_as_time
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `last_performance`, `id`) VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", last_performance: ::Time.parse("2021-05-12T10:30:00+02:00"))
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :TIMESTAMP, request.param_types["p3"].code
      assert_equal "2021-05-12T08:30:00.000000000Z", request.params["p3"]
    end

    def test_create_singer_with_last_performance_as_non_iso_string
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `last_performance`, `id`) VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      # This timestamp string is ambiguous without knowing the locale that it should be parsed in, as it
      # could represent both 4th of July and 7th of April. This test verifies that it is encoded to the
      # same value as ::Time.parse(..) would encode it to.
      timestamp_string = "04/07/2017 2:19pm"
      timestamp = ::Time.parse(timestamp_string)

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", last_performance: timestamp_string)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :TIMESTAMP, request.param_types["p3"].code
      assert_equal timestamp.utc.rfc3339(9), request.params["p3"]
    end

    def test_find_singer_by_last_performance_as_non_iso_string
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`last_performance` = @p1 LIMIT @p2"
      @mock.put_statement_result select_sql, MockServerTests::create_random_singers_result(1)

      # This timestamp string is ambiguous without knowing the locale that should be used for parsing, as it
      # could represent both 4th of July and 7th of April. This test verifies that it is encoded to the
      # same value as ::Time.parse(..) would encode it to.
      timestamp_string = "04/07/2017 2:19pm"
      timestamp = ::Time.parse(timestamp_string)
      Singer.find_by(last_performance: timestamp_string)

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      assert_equal :TIMESTAMP, request.param_types["p1"].code
      assert_equal timestamp.utc.rfc3339(9), request.params["p1"]
    end

    def test_create_singer_with_picture
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `picture`, `id`) VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)
      data = StringIO.new "hello"

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", picture: data)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :BYTES, request.param_types["p3"].code
      assert_equal Base64.strict_encode64("hello".dup.force_encoding("ASCII-8BIT")), request.params["p3"]
    end

    def test_create_singer_with_picture_as_string
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `picture`, `id`) VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)
      data = StringIO.new "hello"

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", picture: data.read)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :BYTES, request.param_types["p3"].code
      assert_equal Base64.strict_encode64("hello".dup.force_encoding("ASCII-8BIT")), request.params["p3"]
    end

    def test_create_singer_with_picture_as_binary
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `picture`, `id`) VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      data = IO.read("#{Dir.pwd}/test/activerecord_spanner_mock_server/cloudspannerlogo.png", mode: "rb")
      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", picture: data)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :BYTES, request.param_types["p3"].code
      assert_equal Base64.strict_encode64(data.force_encoding("ASCII-8BIT")), request.params["p3"]
    end

    def test_create_singer_with_revenues
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `revenues`, `id`) VALUES (@p1, @p2, @p3, @p4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", revenues: 42952.13)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :NUMERIC, request.param_types["p3"].code
      assert_equal "42952.13", request.params["p3"]
    end

    def test_create_album_from_singer
      select_singer_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      insert_album_sql = "INSERT INTO `albums` (`title`, `singer_id`, `id`) VALUES (@p1, @p2, @p3)"

      @mock.put_statement_result select_singer_sql, MockServerTests::create_random_singers_result(1)
      @mock.put_statement_result insert_album_sql, StatementResult.new(1)

      singer = Singer.find_by id: 1
      singer.albums.create title: 'My title'

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_album_sql }.first
      assert_equal :STRING, request.param_types["p1"].code
      assert_equal 'My title', request.params["p1"]
      assert_equal :INT64, request.param_types["p2"].code
      assert_equal :INT64, request.param_types["p3"].code
    end

    def test_delete_all
      @mock.put_statement_result"SELECT COUNT(*) FROM `singers`", StatementResult.create_single_int_result_set("C", 1)
      assert_equal 1, Singer.count

      delete_sql = "DELETE FROM `singers` WHERE TRUE"
      @mock.put_statement_result delete_sql, StatementResult.new(1)
      Singer.transaction do
        Singer.delete_all
      end

      delete_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == delete_sql }
      assert_equal 1, delete_requests.length

      @mock.put_statement_result"SELECT COUNT(*) FROM `singers`", StatementResult.create_single_int_result_set("C", 0)
      assert_equal 0, Singer.count
    end

    def test_destroy_singer
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `id`) VALUES (@p1, @p2, @p3)"
      delete_sql = "DELETE FROM `singers` WHERE `singers`.`id` = @p1"
      @mock.put_statement_result insert_sql, StatementResult.new(1)
      @mock.put_statement_result delete_sql, StatementResult.new(1)

      singer = Singer.create(first_name: "Dave", last_name: "Allison")

      Singer.transaction do
        singer.destroy
      end

      assert_equal 2, @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.count
      delete_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == delete_sql }.first
      assert_equal singer.id.to_s, delete_request.params["p1"]
    end

    def test_singer_albums_uses_prepared_statement
      select_singer_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      select_albums_sql = "SELECT `albums`.* FROM `albums` WHERE `albums`.`singer_id` = @p1"

      @mock.put_statement_result select_singer_sql, MockServerTests::create_random_singers_result(1)
      @mock.put_statement_result select_albums_sql, MockServerTests::create_random_albums_result(2)

      singer = Singer.find_by id: 1
      albums = singer.albums

      assert_equal 2, albums.length
      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_albums_sql }.first
      assert_equal singer.id.to_s, request.params["p1"]
      assert_equal :INT64, request.param_types["p1"].code
    end

    def test_create_singer_using_mutation
      # Create a singer without a transaction block. This will cause the singer to be created using a mutation instead of
      # DML, as it would be impossible to read back the update during the transaction anyways. Mutations are a lot more
      # efficient than DML statements.
      singer = Singer.create(first_name: "Dave", last_name: "Allison")
      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :insert, mutation.operation
      assert_equal "singers", mutation.insert.table

      assert_equal 1, mutation.insert.values.length
      assert_equal 3, mutation.insert.values[0].length
      assert_equal "Dave", mutation.insert.values[0][0]
      assert_equal "Allison", mutation.insert.values[0][1]
      assert_equal singer.id, mutation.insert.values[0][2].to_i

      assert_equal 3, mutation.insert.columns.length
      assert_equal "first_name", mutation.insert.columns[0]
      assert_equal "last_name", mutation.insert.columns[1]
      assert_equal "id", mutation.insert.columns[2]
    end

    def test_update_singer_using_mutation
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      singer = Singer.find_by id: 1

      singer.update last_name: "Allison-Stevenson"

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length

      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :update, mutation.operation
      assert_equal "singers", mutation.update.table

      assert_equal 1, mutation.update.values.length
      assert_equal 2, mutation.update.values[0].length
      assert_equal singer.id, mutation.update.values[0][0].to_i
      assert_equal "Allison-Stevenson", mutation.update.values[0][1]

      assert_equal 2, mutation.update.columns.length
      assert_equal "id", mutation.update.columns[0]
      assert_equal "last_name", mutation.update.columns[1]
    end

    def test_delete_all_using_mutation
      Singer.delete_all

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length

      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :delete, mutation.operation
      assert_equal "singers", mutation.delete.table
      assert mutation.delete.key_set.all
    end

    def test_destroy_singer_using_mutation
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      singer = Singer.find_by id: 1

      singer.destroy

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length

      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :delete, mutation.operation
      assert_equal "singers", mutation.delete.table
      assert_equal 1, mutation.delete.key_set.keys.length
      assert_equal singer.id, mutation.delete.key_set.keys[0][0].to_i
    end

    def test_create_multiple_singers_using_mutations
      # Creating multiple singers without a transaction in one call should only create one transaction.
      Singer.create(
        [
          { first_name: "Dave", last_name: "Allison" },
          { first_name: "Alice", last_name: "Ericsson" },
          { first_name: "Nancy", last_name: "Gardner" }
        ]
      )

      # There should be one commit request with 3 mutations.
      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 3, mutations.length
    end

    def test_create_record_with_commit_timestamp_using_dml
      insert_sql = "INSERT INTO `table_with_commit_timestamps` (`value`, `last_updated`, `id`) VALUES (@p1, PENDING_COMMIT_TIMESTAMP(), @p2)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      row = TableWithCommitTimestamp.transaction do
        TableWithCommitTimestamp.create value: "v1", last_updated: :commit_timestamp
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert request

      # The parameters should only contain the fields `value` and `id`. The `last_updated` field should be supplied
      # using the SQL literal `PENDING_COMMIT_TIMESTAMP()`, which is not allowed as a parameter value.
      assert_equal 2, request.params.fields.length
      assert_equal "v1", request.params["p1"]
      assert_equal :STRING, request.param_types["p1"].code
      assert_equal row.id.to_s, request.params["p2"]
      assert_equal :INT64, request.param_types["p2"].code

    end

    def test_create_record_with_commit_timestamp_using_mutation
      TableWithCommitTimestamp.transaction isolation: :buffered_mutations do
        TableWithCommitTimestamp.create value: "v1", last_updated: :commit_timestamp
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      assert request
      assert request.mutations
      assert_equal 1, request.mutations.length
      mutation = request.mutations[0]
      assert_equal :insert, mutation.operation
      assert_equal "table_with_commit_timestamps", mutation.insert.table

      assert_equal 1, mutation.insert.values.length
      assert_equal 3, mutation.insert.values[0].length
      assert_equal "v1", mutation.insert.values[0][0]
      assert_equal "spanner.commit_timestamp()", mutation.insert.values[0][1]
    end

    def test_create_all_types_using_mutation
      AllTypes.create col_string: "string", col_int64: 100, col_float64: 3.14, col_numeric: 6.626, col_bool: true,
                      col_bytes: StringIO.new("bytes"), col_date: ::Date.new(2021, 6, 23),
                      col_timestamp: ::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"),
                      col_json: { kind: "user_renamed", change: %w[jack john]},
                      col_array_string: ["string1", nil, "string2"],
                      col_array_int64: [100, nil, 200],
                      col_array_float64: [3.14, nil, 2.0/3.0],
                      col_array_numeric: [6.626, nil, 3.20],
                      col_array_bool: [true, nil, false],
                      col_array_bytes: [StringIO.new("bytes1"), nil, StringIO.new("bytes2")],
                      col_array_date: [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)],
                      col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), nil, \
                                            ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")],
                      col_array_json: [{ kind: "user_renamed", change: %w[jack john]}, nil, \
                                       { kind: "user_renamed", change: %w[alice meredith]}]

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 1, mutations.length
      mutation = mutations[0]
      assert_equal :insert, mutation.operation
      assert_equal "all_types", mutation.insert.table

      col_index = -1
      assert_equal "col_string", mutation.insert.columns[col_index += 1]
      assert_equal "col_int64", mutation.insert.columns[col_index += 1]
      assert_equal "col_float64", mutation.insert.columns[col_index += 1]
      assert_equal "col_numeric", mutation.insert.columns[col_index += 1]
      assert_equal "col_bool", mutation.insert.columns[col_index += 1]
      assert_equal "col_bytes", mutation.insert.columns[col_index += 1]
      assert_equal "col_date", mutation.insert.columns[col_index += 1]
      assert_equal "col_timestamp", mutation.insert.columns[col_index += 1]
      assert_equal "col_json", mutation.insert.columns[col_index += 1]

      assert_equal "col_array_string", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_int64", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_float64", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_numeric", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_bool", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_bytes", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_date", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_timestamp", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_json", mutation.insert.columns[col_index += 1]

      value_index = -1
      assert_equal 1, mutation.insert.values.length
      assert_equal "string", mutation.insert.values[0][value_index += 1]
      assert_equal "100", mutation.insert.values[0][value_index += 1]
      assert_equal 3.14, mutation.insert.values[0][value_index += 1]
      assert_equal "6.626", mutation.insert.values[0][value_index += 1]
      assert_equal true, mutation.insert.values[0][value_index += 1]
      assert_equal Base64.urlsafe_encode64("bytes"), mutation.insert.values[0][value_index += 1]
      assert_equal "2021-06-23", mutation.insert.values[0][value_index += 1]
      assert_equal "2021-06-23T15:08:21.000000000Z", mutation.insert.values[0][value_index += 1]
      assert_equal "{\"kind\":\"user_renamed\",\"change\":[\"jack\",\"john\"]}", mutation.insert.values[0][value_index += 1]

      assert_equal create_list_value(["string1", nil, "string2"]), mutation.insert.values[0][value_index += 1]
      assert_equal create_list_value(["100", nil, "200"]), mutation.insert.values[0][value_index += 1]
      assert_equal create_list_value([3.14, nil, 2.0/3.0]), mutation.insert.values[0][value_index += 1]
      assert_equal create_list_value(["6.626", nil, "3.2"]), mutation.insert.values[0][value_index += 1]
      assert_equal create_list_value([true, nil, false]), mutation.insert.values[0][value_index += 1]
      assert_equal create_list_value([
          Base64.urlsafe_encode64("bytes1"),
          nil,
          Base64.urlsafe_encode64("bytes2")
        ]), mutation.insert.values[0][value_index += 1]
      assert_equal \
        create_list_value(["2021-06-23", nil, "2021-06-24"]),
        mutation.insert.values[0][value_index += 1]
      assert_equal create_list_value([
          "2021-06-23T15:08:21.000000000Z",
          nil,
          "2021-06-24T15:08:21.000000000Z"
        ]), mutation.insert.values[0][value_index += 1]
      json_list = create_list_value([
                                      "{\"kind\":\"user_renamed\",\"change\":[\"jack\",\"john\"]}",
                                      nil,
                                      "{\"kind\":\"user_renamed\",\"change\":[\"alice\",\"meredith\"]}"
                                    ])
      assert_equal create_list_value([
          "{\"kind\":\"user_renamed\",\"change\":[\"jack\",\"john\"]}",
          nil,
          "{\"kind\":\"user_renamed\",\"change\":[\"alice\",\"meredith\"]}"
        ]), mutation.insert.values[0][value_index += 1]
    end

    def test_create_all_types_using_dml
      sql = "INSERT INTO `all_types` (`col_string`, `col_int64`, `col_float64`, `col_numeric`, `col_bool`, " \
            "`col_bytes`, `col_date`, `col_timestamp`, `col_json`, `col_array_string`, `col_array_int64`, " \
            "`col_array_float64`, `col_array_numeric`, `col_array_bool`, `col_array_bytes`, `col_array_date`, "\
            "`col_array_timestamp`, `col_array_json`, `id`) "\
            "VALUES (@p1, @p2, @p3, @p4, @p5, @p6, " \
            "@p7, @p8, @p9, @p10, @p11, " \
            "@p12, @p13, @p14, @p15, " \
            "@p16, @p17, @p18, @p19)"
      @mock.put_statement_result sql, StatementResult.new(1)

      AllTypes.transaction do
        AllTypes.create col_string: "string", col_int64: 100, col_float64: 3.14, col_numeric: 6.626, col_bool: true,
                        col_bytes: StringIO.new("bytes"), col_date: ::Date.new(2021, 6, 23),
                        col_timestamp: ::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"),
                        col_json: { kind: "user_renamed", change: %w[jack john]},
                        col_array_string: ["string1", nil, "string2"],
                        col_array_int64: [100, nil, 200],
                        col_array_float64: [3.14, nil, 2.0/3.0],
                        col_array_numeric: [6.626, nil, 3.20],
                        col_array_bool: [true, nil, false],
                        col_array_bytes: [StringIO.new("bytes1"), nil, StringIO.new("bytes2")],
                        col_array_date: [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)],
                        col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), nil, \
                                              ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")],
                        col_array_json: [{ kind: "user_renamed", change: %w[jack john]}, nil, \
                                         { kind: "user_renamed", change: %w[alice meredith]}]
      end

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      assert_empty commit_requests[0].mutations

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }.first
      assert request

      assert_equal "string", request.params["p1"]
      assert_equal :STRING, request.param_types["p1"].code
      assert_equal "100", request.params["p2"]
      assert_equal :INT64, request.param_types["p2"].code
      assert_equal 3.14, request.params["p3"]
      assert_equal :FLOAT64, request.param_types["p3"].code
      assert_equal "6.626", request.params["p4"]
      assert_equal :NUMERIC, request.param_types["p4"].code
      assert_equal true, request.params["p5"]
      assert_equal :BOOL, request.param_types["p5"].code
      assert_equal Base64.urlsafe_encode64("bytes"), request.params["p6"]
      assert_equal :BYTES, request.param_types["p6"].code
      assert_equal "2021-06-23", request.params["p7"]
      assert_equal :DATE, request.param_types["p7"].code
      assert_equal "2021-06-23T15:08:21.000000000Z", request.params["p8"]
      assert_equal :TIMESTAMP, request.param_types["p8"].code
      assert_equal "{\"kind\":\"user_renamed\",\"change\":[\"jack\",\"john\"]}", request.params["p9"]
      assert_equal :JSON, request.param_types["p9"].code

      assert_equal create_list_value(["string1", nil, "string2"]), request.params["p10"]
      assert_equal :ARRAY, request.param_types["p10"].code
      assert_equal :STRING, request.param_types["p10"].array_element_type.code
      assert_equal create_list_value(["100", nil, "200"]), request.params["p11"]
      assert_equal :ARRAY, request.param_types["p11"].code
      assert_equal :INT64, request.param_types["p11"].array_element_type.code
      assert_equal create_list_value([3.14, nil, 2.0/3.0]), request.params["p12"]
      assert_equal :ARRAY, request.param_types["p12"].code
      assert_equal :FLOAT64, request.param_types["p12"].array_element_type.code
      assert_equal create_list_value(["6.626", nil, "3.2"]), request.params["p13"]
      assert_equal :ARRAY, request.param_types["p13"].code
      assert_equal :NUMERIC, request.param_types["p13"].array_element_type.code
      assert_equal create_list_value([true, nil, false]), request.params["p14"]
      assert_equal :ARRAY, request.param_types["p14"].code
      assert_equal :BOOL, request.param_types["p14"].array_element_type.code
      assert_equal create_list_value([Base64.urlsafe_encode64("bytes1"), nil, Base64.urlsafe_encode64("bytes2")]),
                   request.params["p15"]
      assert_equal :ARRAY, request.param_types["p15"].code
      assert_equal :BYTES, request.param_types["p15"].array_element_type.code
      assert_equal create_list_value(["2021-06-23", nil, "2021-06-24"]), request.params["p16"]
      assert_equal :ARRAY, request.param_types["p16"].code
      assert_equal :DATE, request.param_types["p16"].array_element_type.code
      assert_equal create_list_value(["2021-06-23T15:08:21.000000000Z", nil, "2021-06-24T15:08:21.000000000Z"]),
                   request.params["p17"]
      assert_equal :ARRAY, request.param_types["p17"].code
      assert_equal :TIMESTAMP, request.param_types["p17"].array_element_type.code
      assert_equal create_list_value(["2021-06-23T15:08:21.000000000Z", nil, "2021-06-24T15:08:21.000000000Z"]),
                   request.params["p17"]
      assert_equal :ARRAY, request.param_types["p18"].code
      assert_equal :JSON, request.param_types["p18"].array_element_type.code
      assert_equal create_list_value(["{\"kind\":\"user_renamed\",\"change\":[\"jack\",\"john\"]}", nil, \
                                      "{\"kind\":\"user_renamed\",\"change\":[\"alice\",\"meredith\"]}"]),
                   request.params["p18"]
    end

    def test_get_json
      sql = "SELECT `all_types`.* FROM `all_types` WHERE `all_types`.`col_int64` = @p1 LIMIT @p2"
      col_id = Google::Cloud::Spanner::V1::StructType::Field.new name: "col_int64", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
      col_json = Google::Cloud::Spanner::V1::StructType::Field.new name: "col_json", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::JSON)
      col_json_array = Google::Cloud::Spanner::V1::StructType::Field.new name: "col_array_json", type: Google::Cloud::Spanner::V1::Type.new(
        code: Google::Cloud::Spanner::V1::TypeCode::ARRAY,
        array_element_type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::JSON)
      )
      metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
      metadata.row_type.fields.push(col_id, col_json, col_json_array)
      result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata
      row = Google::Protobuf::ListValue.new
      json_array = Google::Protobuf::ListValue.new
      json_array.values.push(
        Google::Protobuf::Value.new(string_value: "{\"key1\": \"value1\"}"),
        Google::Protobuf::Value.new(null_value: "NULL_VALUE"),
        Google::Protobuf::Value.new(string_value: "{\"key2\": \"value2\"}")
      )
      row.values.push(
        Google::Protobuf::Value.new(string_value: "1"),
        Google::Protobuf::Value.new(string_value: "{\"key\": \"value\"}"),
        Google::Protobuf::Value.new(list_value: json_array)
      )
      result_set.rows.push row
      @mock.put_statement_result sql, StatementResult.new(result_set)

      row = AllTypes.find_by col_int64: 1
      assert_equal ({"key"=>"value"}), row.col_json
      assert_equal [{"key1"=>"value1"}, nil, {"key2"=>"value2"}], row.col_array_json
    end

    def test_delete_associated_records
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      albums_sql = "SELECT `albums`.* FROM `albums` WHERE `albums`.`singer_id` = @p1"
      @mock.put_statement_result albums_sql, MockServerTests::create_random_albums_result(2)
      singer = Singer.find_by id: 1

      update_albums_sql = ActiveRecord::gem_version < VERSION_7_1_0 \
                     ? "UPDATE `albums` SET `singer_id` = @p1 WHERE `albums`.`singer_id` = @p2 AND `albums`.`id` IN (@p3, @p4)"
                     : "UPDATE `albums` SET `singer_id` = @p1 WHERE `albums`.`singer_id` = @p2 AND (`albums`.`id` = @p3 OR `albums`.`id` = @p4)"
      @mock.put_statement_result update_albums_sql, StatementResult.new(2)

      singer.albums = []
      singer.reload

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_albums_sql }.first
      assert request
    end

    def test_pdml
      update_sql = "UPDATE `singers` SET `last_name` = @p1 WHERE TRUE"
      @mock.put_statement_result update_sql, StatementResult.new(1)

      Singer.transaction isolation: :pdml do
        Singer.update_all last_name: "NewName"
      end

      begin_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }.first
      assert begin_request&.options&.partitioned_dml
      update_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }.first
      assert update_request&.transaction&.id
      # PDML transactions should not be committed.
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      refute commit_request
    end

    def test_delete_all_pdml
      delete_sql = "DELETE FROM `singers` WHERE TRUE"
      @mock.put_statement_result delete_sql, StatementResult.new(100)

      Singer.transaction isolation: :pdml do
        Singer.delete_all
      end

      begin_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_requests.length
      begin_request = begin_requests.first
      assert begin_request&.options&.partitioned_dml
      delete_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == delete_sql }.first
      assert delete_request&.transaction&.id
      # PDML transactions should not be committed.
      commit_request = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::CommitRequest }.first
      refute commit_request
    end

    def test_statement_hint
      sql = " @{USE_ADDITIONAL_PARALLELISM=true, OPTIMIZER_STATISTICS_PACKAGE='stats-package-1'}SELECT  `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)

      Singer.optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true, OPTIMIZER_STATISTICS_PACKAGE='stats-package-1'}").find_by(id: 1)

      execute_sql_request = @mock.requests.find { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      assert_equal sql, execute_sql_request.sql
    end

    def test_statement_and_staleness_hint
      sql = " @{USE_ADDITIONAL_PARALLELISM=true}SELECT  `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)

      Singer
        .optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true}")
        .optimizer_hints("min_read_timestamp: 2021-09-07T14:33:30.1123Z")
        .find_by(id: 1)

      execute_sql_request = @mock.requests.find { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      assert_equal sql, execute_sql_request.sql
      single_use = execute_sql_request.transaction.single_use
      assert single_use
      assert single_use.read_only.return_read_timestamp
      assert single_use.read_only.min_read_timestamp
      time = Google::Cloud::Spanner::Convert.time_to_timestamp Time.xmlschema("2021-09-07T14:33:30.1123Z")
      assert_equal time, single_use.read_only.min_read_timestamp
    end

    def test_table_hint
      sql = "SELECT  `singers`.* FROM `singers`@{FORCE_INDEX=idx_singers_full_name} WHERE `singers`.`id` = @p1 LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)

      Singer.optimizer_hints("table_hint: singers@{FORCE_INDEX=idx_singers_full_name}").find_by(id: 1)

      execute_sql_request = @mock.requests.find { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      assert_equal sql, execute_sql_request.sql
    end

    def test_multiple_table_hints
      sql = "SELECT  `singers`.* FROM `singers`@{FORCE_INDEX=idx_singers_full_name} INNER JOIN `albums`@{FORCE_INDEX=_BASE_TABLE} ON `albums`.`singer_id` = `singers`.`id` WHERE (albums.title='test') ORDER BY `singers`.`id` ASC LIMIT @p1"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)

      Singer.optimizer_hints("table_hint: singers@{FORCE_INDEX=idx_singers_full_name}")
            .optimizer_hints("table_hint: albums@{FORCE_INDEX=_BASE_TABLE}")
            .joins(:albums)
            .where("albums.title='test'")
            .first

      execute_sql_request = @mock.requests.find { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      assert_equal sql, execute_sql_request.sql
    end

    def test_multiple_table_and_statement_hints
      sql = " @{USE_ADDITIONAL_PARALLELISM=true}SELECT  `singers`.* FROM `singers`@{FORCE_INDEX=idx_singers_full_name} INNER JOIN `albums`@{FORCE_INDEX=_BASE_TABLE} ON `albums`.`singer_id` = `singers`.`id` WHERE (albums.title='test') ORDER BY `singers`.`id` ASC LIMIT @p1"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)

      Singer.optimizer_hints("table_hint: singers@{FORCE_INDEX=idx_singers_full_name}")
            .optimizer_hints("table_hint: albums@{FORCE_INDEX=_BASE_TABLE}")
            .optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true}")
            .optimizer_hints("min_read_timestamp: 2021-09-07T14:33:30.1123Z")
            .joins(:albums)
            .where("albums.title='test'")
            .first

      execute_sql_request = @mock.requests.find { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      assert_equal sql, execute_sql_request.sql
      single_use = execute_sql_request.transaction.single_use
      assert single_use
      assert single_use.read_only.return_read_timestamp
      assert single_use.read_only.min_read_timestamp
      time = Google::Cloud::Spanner::Convert.time_to_timestamp Time.xmlschema("2021-09-07T14:33:30.1123Z")
      assert_equal time, single_use.read_only.min_read_timestamp
    end

    def test_join_hint
      sql = "SELECT `singers`.* FROM `singers` INNER JOIN @{JOIN_METHOD=HASH_JOIN, FORCE_JOIN_ORDER=TRUE} albums ON albums.singer_id=singers.id WHERE (albums.title='test') ORDER BY `singers`.`id` ASC LIMIT @p1"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)

      # Joins can be customized by specifying them as strings, so we don't have to use any custom optimizer hints.
      Singer.joins("INNER JOIN @{JOIN_METHOD=HASH_JOIN, FORCE_JOIN_ORDER=TRUE} albums ON albums.singer_id=singers.id")
            .where("albums.title='test'")
            .first

      execute_sql_request = @mock.requests.find { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      assert_equal sql, execute_sql_request.sql
    end

    def test_query_annotate_request_tag
      sql = "SELECT `singers`.* FROM `singers` /* request_tag: selecting all singers */"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(4)
      Singer.annotate("request_tag: selecting all singers").all.each do |singer|
        refute_nil singer.id, "singer.id should not be nil"
      end
      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      select_requests.each do |request|
        assert request.request_options
        assert_equal "selecting all singers", request.request_options.request_tag
      end
    end

    def test_query_annotate_transaction_tag
      sql = "SELECT `singers`.* FROM `singers` /* transaction_tag: selecting all singers */"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(4)
      Singer.annotate("transaction_tag: selecting all singers").all.each do |singer|
        refute_nil singer.id, "singer.id should not be nil"
      end
      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      select_requests.each do |request|
        assert request.request_options
        assert_equal "selecting all singers", request.request_options.transaction_tag
      end
    end

    def test_query_annotate_request_and_transaction_tag
      sql = "SELECT `singers`.* FROM `singers` /* transaction_tag: tx tag */ /* request_tag: req tag */"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(4)
      Singer.annotate("transaction_tag: tx tag", "request_tag: req tag").all.each do |singer|
        refute_nil singer.id, "singer.id should not be nil"
      end
      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      select_requests.each do |request|
        assert request.request_options
        assert_equal "req tag", request.request_options.request_tag
        assert_equal "tx tag", request.request_options.transaction_tag
      end
    end

    def test_query_annotate_request_and_transaction_tag_and_binds
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @p1 /* transaction_tag: tx tag */ /* request_tag: req tag */ LIMIT @p2"
      @mock.put_statement_result sql, MockServerTests::create_random_singers_result(1)
      singer = Singer.annotate("transaction_tag: tx tag", "request_tag: req tag").find_by id: 1
      assert singer

      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }
      select_requests.each do |request|
        assert request.request_options
        assert_equal "req tag", request.request_options.request_tag
        assert_equal "tx tag", request.request_options.transaction_tag
        assert_equal 2, request.params.fields.length
        assert_equal "1", request.params["p2"]
        assert_equal "1", request.params["p1"]
        assert_equal :INT64, request.param_types["p2"].code
        assert_equal :INT64, request.param_types["p1"].code
      end
    end

    def test_query_logs
      skip "Requires Rails version 7.0 or higher" if ActiveRecord::VERSION::MAJOR < 7

      begin
        current_query_transformers = _enable_query_logs

        sql = "/*request_tag:true,action:test_query_logs*/ SELECT `singers`.* FROM `singers`"
        @mock.put_statement_result sql, MockServerTests::create_random_singers_result(4)
        Singer.all.each do |singer|
          refute_nil singer.id, "singer.id should not be nil"
        end
        select_requests = @mock.requests.select { |req| req.is_a?(ExecuteSqlRequest) && req.sql == sql }
        select_requests.each do |request|
          assert request.request_options
          assert_equal "action:test_query_logs", request.request_options.request_tag
        end
      ensure
        _disable_query_logs current_query_transformers
      end
    end

    def test_query_logs_combined_with_request_tag
      skip "Requires Rails version 7.0 or higher" if ActiveRecord::VERSION::MAJOR < 7

      begin
        current_query_transformers = _enable_query_logs

        sql = "/*request_tag:true,action:test_query_logs*/ SELECT `singers`.* FROM `singers` /* request_tag: selecting all singers */"
        @mock.put_statement_result sql, MockServerTests::create_random_singers_result(4)
        Singer.annotate("request_tag: selecting all singers").all.each do |singer|
          refute_nil singer.id, "singer.id should not be nil"
        end
        select_requests = @mock.requests.select { |req| req.is_a?(ExecuteSqlRequest) && req.sql == sql }
        select_requests.each do |request|
          assert request.request_options
          assert_equal "selecting all singers,action:test_query_logs", request.request_options.request_tag
        end
      ensure
        _disable_query_logs current_query_transformers
      end
    end

    def _enable_query_logs
      # Make sure that the comment that is added by query_logs is actually added to the query string.
      # The comment is not translated to a request tag, because the comment is added at a too late moment.
      # Instead, we need to add that at a lower level in the Spanner connection.

      # Simulate that query_logs has been enabled.
      current_query_transformers = ActiveRecord.query_transformers

      ActiveRecord.query_transformers << ActiveRecord::QueryLogs
      ActiveRecord::QueryLogs.prepend_comment = true
      ActiveRecord::QueryLogs.taggings.merge!(
        application:  "test-app",
        action:       "test_query_logs",
        pid:          -> { Process.pid.to_s },
      )
      ActiveRecord::QueryLogs.tags = [
        {
          request_tag:  "true",
        },
        :controller,
        :action,
        :job,
        {
          request_id: ->(context) { context[:controller]&.request&.request_id },
          job_id: ->(context) { context[:job]&.job_id },
        },
        :db_host,
        :database
      ]

      current_query_transformers
    end

    def _disable_query_logs current_query_transformers
      current_query_transformers.each do |transformer|
        ActiveRecord.query_transformers.delete transformer
      end
    end

    def test_insert_all
      values = [
        {id: 1, first_name: "Dave", last_name: "Allison"},
        {id: 2, first_name: "Alice", last_name: "Davidson"},
        {id: 3, first_name: "Rene", last_name: "Henderson"},
      ]
      assert_raises(NotImplementedError) { Singer.insert_all values }
    end

    def test_insert_all_bang_mutations
      values = [
        {id: 1, first_name: "Dave", last_name: "Allison"},
        {id: 2, first_name: "Alice", last_name: "Davidson"},
        {id: 3, first_name: "Rene", last_name: "Henderson"},
      ]

      [true, false].each do |use_transaction|
        @mock.requests.clear

        if use_transaction
          Singer.insert_all! values
        else
          Singer.transaction isolation: :buffered_mutations do
            Singer.insert_all! values
          end
        end

        verify_insert_upsert_all :insert
      end
    end

    def test_insert_all_bang_dml
      insert_sql_2_5 = "INSERT INTO `singers`(`id`,`first_name`,`last_name`) VALUES (1, 'Dave', 'Allison'), (2, 'Alice', 'Davidson'), (3, 'Rene', 'Henderson')"
      insert_sql = "INSERT INTO `singers` (`id`,`first_name`,`last_name`) VALUES (1, 'Dave', 'Allison'), (2, 'Alice', 'Davidson'), (3, 'Rene', 'Henderson')"
      @mock.put_statement_result insert_sql_2_5, StatementResult.new(3)
      @mock.put_statement_result insert_sql, StatementResult.new(3)

      values = [
        {id: 1, first_name: "Dave", last_name: "Allison"},
        {id: 2, first_name: "Alice", last_name: "Davidson"},
        {id: 3, first_name: "Rene", last_name: "Henderson"},
      ]
      Singer.transaction do
        Singer.insert_all! values
      end

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      assert_equal 0, commit_requests[0].mutations.length
      execute_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && (req.sql == insert_sql || req.sql == insert_sql_2_5) }
      assert_equal 1, execute_requests.length
    end

    def test_upsert_all_mutations
      values = [
        {id: 1, first_name: "Dave", last_name: "Allison"},
        {id: 2, first_name: "Alice", last_name: "Davidson"},
        {id: 3, first_name: "Rene", last_name: "Henderson"},
      ]

      [true, false].each do |use_transaction|
        @mock.requests.clear

        if use_transaction
          Singer.upsert_all values
        else
          Singer.transaction isolation: :buffered_mutations do
            Singer.upsert_all values
          end
        end

        verify_insert_upsert_all :insert_or_update
      end
    end

    def test_upsert_all_dml
      values = [
        {id: 1, first_name: "Dave", last_name: "Allison"},
        {id: 2, first_name: "Alice", last_name: "Davidson"},
        {id: 3, first_name: "Rene", last_name: "Henderson"},
      ]
      err = assert_raises(NotImplementedError) do
        Singer.transaction do
          Singer.upsert_all values
        end
      end
      assert_match "Use upsert outside a transaction block", err.message
    end

    private

    def verify_insert_upsert_all operation
      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      mutations = commit_requests[0].mutations
      assert_equal 3, mutations.length
      mutation = mutations[0]
      assert_equal operation, mutation.operation
      write = mutation["#{operation}"]
      assert_equal "singers", write.table

      assert_equal 1, write.values.length
      assert_equal 3, write.values[0].length
      assert_equal 1, write.values[0][0].to_i
      assert_equal "Dave", write.values[0][1]
      assert_equal "Allison", write.values[0][2]

      assert_equal 3, write.columns.length
      assert_equal "id", write.columns[0]
      assert_equal "first_name", write.columns[1]
      assert_equal "last_name", write.columns[2]

      mutation = mutations[1]
      assert_equal operation, mutation.operation
      write = mutation["#{operation}"]
      assert_equal "singers", write.table

      assert_equal 1, write.values.length
      assert_equal 3, write.values[0].length
      assert_equal 2, write.values[0][0].to_i
      assert_equal "Alice", write.values[0][1]
      assert_equal "Davidson", write.values[0][2]

      mutation = mutations[2]
      assert_equal operation, mutation.operation
      write = mutation["#{operation}"]
      assert_equal "singers", write.table

      assert_equal 1, write.values.length
      assert_equal 3, write.values[0].length
      assert_equal 3, write.values[0][0].to_i
      assert_equal "Rene", write.values[0][1]
      assert_equal "Henderson", write.values[0][2]
    end

    def create_list_value values
      Google::Protobuf::ListValue.new values: (values.map do |value|
        next Google::Protobuf::Value.new null_value: "NULL_VALUE" if value.nil?
        next Google::Protobuf::Value.new string_value: value if value.is_a?(String)
        next Google::Protobuf::Value.new number_value: value if value.is_a?(Float)
        next Google::Protobuf::Value.new bool_value: value if [true, false].include?(value)
        raise StandardError, "Unknown value: #{value}"
      end.to_a)
    end
  end
end
