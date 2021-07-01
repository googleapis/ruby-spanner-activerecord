# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./base_spanner_mock_server_test"

module MockServerTests
  class SpannerActiveRecordMockServerTest < BaseSpannerMockServerTest

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
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
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
        assert_equal "1", request.params["LIMIT_2"]
        assert_equal "1", request.params["id_1"]
        assert_equal :INT64, request.param_types["LIMIT_2"].code
        assert_equal :INT64, request.param_types["id_1"].code
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
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
      @mock.put_statement_result select_sql, MockServerTests::create_random_singers_result(1)

      singer = Singer.find_by id: 1

      update_sql = "UPDATE `singers` SET `first_name` = @first_name_1 WHERE `singers`.`id` = @id_2"
      @mock.put_statement_result update_sql, StatementResult.new(1)

      singer.first_name = 'Dave'
      singer.save!

      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_transaction_requests.length
      # Check the encoded parameters.
      select_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }
      select_requests.each do |request|
        assert_equal "Dave", request.params["first_name_1"]
        assert_equal singer.id.to_s, request.params["id_2"]
        assert_equal :STRING, request.param_types["first_name_1"].code
        assert_equal :INT64, request.param_types["id_2"].code
      end
    end

    def test_update_two_singers_should_use_transaction
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` BETWEEN @id_1 AND @id_2"
      @mock.put_statement_result select_sql, MockServerTests::create_random_singers_result(2)

      update_sql = "UPDATE `singers` SET `first_name` = @first_name_1 WHERE `singers`.`id` = @id_2"
      ActiveRecord::Base.transaction do
        singers = Singer.where id: 1..2
        @mock.put_statement_result update_sql, StatementResult.new(1)

        singers[0].update! first_name: "Name1"
        singers[1].update! first_name: "Name2"
      end

      begin_transaction_requests = @mock.requests.select { |req| req.is_a? Google::Cloud::Spanner::V1::BeginTransactionRequest }
      assert_equal 1, begin_transaction_requests.length
      # All of the SQL requests should use a transaction.
      sql_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && (req.sql.starts_with?("SELECT `singers`.*") || req.sql.starts_with?("UPDATE")) }
      sql_requests.each do |request|
        refute_nil request.transaction
        @id ||= request.transaction.id
        assert_equal @id, request.transaction.id
      end

      update_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == update_sql }
      assert_equal 2, update_requests.length

      singers = Singer.where id: 1..2
      update_requests.each_with_index do |request, index|
        assert_equal "Name#{index+1}", request.params["first_name_1"]
        assert_equal "#{singers[index].id}", request.params["id_2"]
        assert_equal :STRING, request.param_types["first_name_1"].code
        assert_equal :INT64, request.param_types["id_2"].code
      end
    end

    def test_create_singer_with_last_performance_as_time
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `last_performance`, `id`) VALUES (@first_name_1, @last_name_2, @last_performance_3, @id_4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", last_performance: ::Time.parse("2021-05-12T10:30:00+02:00"))
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :TIMESTAMP, request.param_types["last_performance_3"].code
      assert_equal "2021-05-12T08:30:00.000000000Z", request.params["last_performance_3"]
    end

    def test_create_singer_with_last_performance_as_non_iso_string
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `last_performance`, `id`) VALUES (@first_name_1, @last_name_2, @last_performance_3, @id_4)"
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
      assert_equal :TIMESTAMP, request.param_types["last_performance_3"].code
      assert_equal timestamp.utc.rfc3339(9), request.params["last_performance_3"]
    end

    def test_find_singer_by_last_performance_as_non_iso_string
      select_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`last_performance` = @last_performance_1 LIMIT @LIMIT_2"
      @mock.put_statement_result select_sql, MockServerTests::create_random_singers_result(1)

      # This timestamp string is ambiguous without knowing the locale that should be used for parsing, as it
      # could represent both 4th of July and 7th of April. This test verifies that it is encoded to the
      # same value as ::Time.parse(..) would encode it to.
      timestamp_string = "04/07/2017 2:19pm"
      timestamp = ::Time.parse(timestamp_string)
      Singer.find_by(last_performance: timestamp_string)

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_sql }.first
      assert_equal :TIMESTAMP, request.param_types["last_performance_1"].code
      assert_equal timestamp.utc.rfc3339(9), request.params["last_performance_1"]
    end

    def test_create_singer_with_picture
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `picture`, `id`) VALUES (@first_name_1, @last_name_2, @picture_3, @id_4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)
      data = StringIO.new "hello"

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", picture: data)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :BYTES, request.param_types["picture_3"].code
      assert_equal Base64.strict_encode64("hello".dup.force_encoding("ASCII-8BIT")), request.params["picture_3"]
    end

    def test_create_singer_with_picture_as_string
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `picture`, `id`) VALUES (@first_name_1, @last_name_2, @picture_3, @id_4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)
      data = StringIO.new "hello"

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", picture: data.read)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :BYTES, request.param_types["picture_3"].code
      assert_equal Base64.strict_encode64("hello".dup.force_encoding("ASCII-8BIT")), request.params["picture_3"]
    end

    def test_create_singer_with_picture_as_binary
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `picture`, `id`) VALUES (@first_name_1, @last_name_2, @picture_3, @id_4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      data = IO.read("#{Dir.pwd}/test/activerecord_spanner_mock_server/cloudspannerlogo.png", mode: "rb")
      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", picture: data)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :BYTES, request.param_types["picture_3"].code
      assert_equal Base64.strict_encode64(data.force_encoding("ASCII-8BIT")), request.params["picture_3"]
    end

    def test_create_singer_with_revenues
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `revenues`, `id`) VALUES (@first_name_1, @last_name_2, @revenues_3, @id_4)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      Singer.transaction do
        Singer.create(first_name: "Dave", last_name: "Allison", revenues: 42952.13)
      end

      request = @mock.requests.select {|req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert_equal :NUMERIC, request.param_types["revenues_3"].code
      assert_equal "42952.13", request.params["revenues_3"]
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
      insert_sql = "INSERT INTO `singers` (`first_name`, `last_name`, `id`) VALUES (@first_name_1, @last_name_2, @id_3)"
      delete_sql = "DELETE FROM `singers` WHERE `singers`.`id` = @id_1"
      @mock.put_statement_result insert_sql, StatementResult.new(1)
      @mock.put_statement_result delete_sql, StatementResult.new(1)

      singer = Singer.create(first_name: "Dave", last_name: "Allison")

      Singer.transaction do
        singer.destroy
      end

      assert_equal 2, @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.count
      delete_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == delete_sql }.first
      assert_equal singer.id.to_s, delete_request.params["id_1"]
    end

    def test_singer_albums_uses_prepared_statement
      select_singer_sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
      select_albums_sql = "SELECT `albums`.* FROM `albums` WHERE `albums`.`singer_id` = @singer_id_1"

      @mock.put_statement_result select_singer_sql, MockServerTests::create_random_singers_result(1)
      @mock.put_statement_result select_albums_sql, MockServerTests::create_random_albums_result(2)

      singer = Singer.find_by id: 1
      albums = singer.albums

      assert_equal 2, albums.length
      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == select_albums_sql }.first
      assert_equal singer.id.to_s, request.params["singer_id_1"]
      assert_equal :INT64, request.param_types["singer_id_1"].code
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
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
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
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`id` = @id_1 LIMIT @LIMIT_2"
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
      insert_sql = "INSERT INTO `table_with_commit_timestamps` (`value`, `last_updated`, `id`) VALUES (@value_1, PENDING_COMMIT_TIMESTAMP(), @id_2)"
      @mock.put_statement_result insert_sql, StatementResult.new(1)

      TableWithCommitTimestamp.transaction do
        TableWithCommitTimestamp.create value: "v1", last_updated: :commit_timestamp
      end

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == insert_sql }.first
      assert request

      # The parameters should only contain the fields `value` and `id`. The `last_updated` field should be supplied
      # using the SQL literal `PENDING_COMMIT_TIMESTAMP()`, which is not allowed as a parameter value.
      assert_equal 2, request.params.fields.length
      assert_equal "v1", request.params["value_1"]
      assert_equal :STRING, request.param_types["value_1"].code
      refute request.params["last_updated_2"]
      refute request.param_types["last_updated_2"]

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
                      col_array_string: ["string1", nil, "string2"],
                      col_array_int64: [100, nil, 200],
                      col_array_float64: [3.14, nil, 2.0/3.0],
                      col_array_numeric: [6.626, nil, 3.20],
                      col_array_bool: [true, nil, false],
                      col_array_bytes: [StringIO.new("bytes1"), nil, StringIO.new("bytes2")],
                      col_array_date: [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)],
                      col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), nil, \
                                            ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")]

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

      assert_equal "col_array_string", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_int64", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_float64", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_numeric", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_bool", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_bytes", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_date", mutation.insert.columns[col_index += 1]
      assert_equal "col_array_timestamp", mutation.insert.columns[col_index += 1]

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
    end

    def test_create_all_types_using_dml
      sql = "INSERT INTO `all_types` (`col_string`, `col_int64`, `col_float64`, `col_numeric`, `col_bool`, " \
            "`col_bytes`, `col_date`, `col_timestamp`, `col_array_string`, `col_array_int64`, `col_array_float64`, "\
            "`col_array_numeric`, `col_array_bool`, `col_array_bytes`, `col_array_date`, `col_array_timestamp`, `id`) "\
            "VALUES (@col_string_1, @col_int64_2, @col_float64_3, @col_numeric_4, @col_bool_5, @col_bytes_6, " \
            "@col_date_7, @col_timestamp_8, @col_array_string_9, @col_array_int64_10, @col_array_float64_11, " \
            "@col_array_numeric_12, @col_array_bool_13, @col_array_bytes_14, @col_array_date_15, " \
            "@col_array_timestamp_16, @id_17)"
      @mock.put_statement_result sql, StatementResult.new(1)

      AllTypes.transaction do
        AllTypes.create col_string: "string", col_int64: 100, col_float64: 3.14, col_numeric: 6.626, col_bool: true,
                        col_bytes: StringIO.new("bytes"), col_date: ::Date.new(2021, 6, 23),
                        col_timestamp: ::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"),
                        col_array_string: ["string1", nil, "string2"],
                        col_array_int64: [100, nil, 200],
                        col_array_float64: [3.14, nil, 2.0/3.0],
                        col_array_numeric: [6.626, nil, 3.20],
                        col_array_bool: [true, nil, false],
                        col_array_bytes: [StringIO.new("bytes1"), nil, StringIO.new("bytes2")],
                        col_array_date: [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)],
                        col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), nil, \
                                              ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")]
      end

      commit_requests = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }
      assert_equal 1, commit_requests.length
      assert_empty commit_requests[0].mutations

      request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::ExecuteSqlRequest) && req.sql == sql }.first
      assert request

      assert_equal "string", request.params["col_string_1"]
      assert_equal :STRING, request.param_types["col_string_1"].code
      assert_equal "100", request.params["col_int64_2"]
      assert_equal :INT64, request.param_types["col_int64_2"].code
      assert_equal 3.14, request.params["col_float64_3"]
      assert_equal :FLOAT64, request.param_types["col_float64_3"].code
      assert_equal "6.626", request.params["col_numeric_4"]
      assert_equal :NUMERIC, request.param_types["col_numeric_4"].code
      assert_equal true, request.params["col_bool_5"]
      assert_equal :BOOL, request.param_types["col_bool_5"].code
      assert_equal Base64.urlsafe_encode64("bytes"), request.params["col_bytes_6"]
      assert_equal :BYTES, request.param_types["col_bytes_6"].code
      assert_equal "2021-06-23", request.params["col_date_7"]
      assert_equal :DATE, request.param_types["col_date_7"].code
      assert_equal "2021-06-23T15:08:21.000000000Z", request.params["col_timestamp_8"]
      assert_equal :TIMESTAMP, request.param_types["col_timestamp_8"].code

      assert_equal create_list_value(["string1", nil, "string2"]), request.params["col_array_string_9"]
      assert_equal :ARRAY, request.param_types["col_array_string_9"].code
      assert_equal :STRING, request.param_types["col_array_string_9"].array_element_type.code
      assert_equal create_list_value(["100", nil, "200"]), request.params["col_array_int64_10"]
      assert_equal :ARRAY, request.param_types["col_array_int64_10"].code
      assert_equal :INT64, request.param_types["col_array_int64_10"].array_element_type.code
      assert_equal create_list_value([3.14, nil, 2.0/3.0]), request.params["col_array_float64_11"]
      assert_equal :ARRAY, request.param_types["col_array_float64_11"].code
      assert_equal :FLOAT64, request.param_types["col_array_float64_11"].array_element_type.code
      assert_equal create_list_value(["6.626", nil, "3.2"]), request.params["col_array_numeric_12"]
      assert_equal :ARRAY, request.param_types["col_array_numeric_12"].code
      assert_equal :NUMERIC, request.param_types["col_array_numeric_12"].array_element_type.code
      assert_equal create_list_value([true, nil, false]), request.params["col_array_bool_13"]
      assert_equal :ARRAY, request.param_types["col_array_bool_13"].code
      assert_equal :BOOL, request.param_types["col_array_bool_13"].array_element_type.code
      assert_equal create_list_value([Base64.urlsafe_encode64("bytes1"), nil, Base64.urlsafe_encode64("bytes2")]),
                   request.params["col_array_bytes_14"]
      assert_equal :ARRAY, request.param_types["col_array_bytes_14"].code
      assert_equal :BYTES, request.param_types["col_array_bytes_14"].array_element_type.code
      assert_equal create_list_value(["2021-06-23", nil, "2021-06-24"]), request.params["col_array_date_15"]
      assert_equal :ARRAY, request.param_types["col_array_date_15"].code
      assert_equal :DATE, request.param_types["col_array_date_15"].array_element_type.code
      assert_equal create_list_value(["2021-06-23T15:08:21.000000000Z", nil, "2021-06-24T15:08:21.000000000Z"]),
                   request.params["col_array_timestamp_16"]
      assert_equal :ARRAY, request.param_types["col_array_timestamp_16"].code
      assert_equal :TIMESTAMP, request.param_types["col_array_timestamp_16"].array_element_type.code
    end

    private

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
