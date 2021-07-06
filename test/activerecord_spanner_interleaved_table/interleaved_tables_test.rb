# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require_relative "./model_helper"
require_relative "../mock_server/spanner_mock_server"
require_relative "../test_helper"
require_relative "models/singer"
require_relative "models/album"
require_relative "models/track"

require "securerandom"

module TestInterleavedTables
  class InterleavedTablesTest < Minitest::Test
    def setup
      super
      @server = GRPC::RpcServer.new
      @port = @server.add_http2_port "localhost:0", :this_port_is_insecure
      @mock = SpannerMockServer.new
      @server.handle @mock
      # Run the server in a separate thread
      @server_thread = Thread.new do
        @server.run
      end
      @server.wait_till_running
      # Register INFORMATION_SCHEMA queries on the mock server.
      TestInterleavedTables::register_select_tables_result @mock
      TestInterleavedTables::register_singers_columns_result @mock
      TestInterleavedTables::register_singers_primary_key_columns_result @mock
      TestInterleavedTables::register_albums_columns_result @mock
      TestInterleavedTables::register_albums_primary_key_columns_result @mock
      TestInterleavedTables::register_albums_primary_and_parent_key_columns_result @mock
      TestInterleavedTables::register_tracks_columns_result @mock
      TestInterleavedTables::register_tracks_primary_key_columns_result @mock
      TestInterleavedTables::register_tracks_primary_and_parent_key_columns_result @mock
      # Connect ActiveRecord to the mock server
      ActiveRecord::Base.establish_connection(
        adapter: "spanner",
        emulator_host: "localhost:#{@port}",
        project: "test-project",
        instance: "test-instance",
        database: "testdb",
      )
      ActiveRecord::Base.logger = nil
    end

    def teardown
      ActiveRecord::Base.connection_pool.disconnect!
      @server.stop
      @server_thread.exit
      super
    end

    def test_select_all_albums
      sql = "SELECT `albums`.* FROM `albums`"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_albums_result(4)
      Album.all.each do |album|
        refute_nil album.albumid, "albumid should not be nil"
        refute_nil album.singerid, "singerid should not be nil"
      end
    end

    def test_find_album
      # Selecting a single album should only use the albumid column, and not the singerid column that is technically also
      # part of the primary key.
      sql = "SELECT `albums`.* FROM `albums` WHERE `albums`.`albumid` = @albumid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_albums_result(1)
      album = Album.find 1
      refute_nil album.albumid, "albumid should not be nil"
      refute_nil album.singerid, "singerid should not be nil"
    end

    def test_create_album
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`singerid` = @singerid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_singers_result(1)
      singer = Singer.find 1

      album = Album.create singer: singer, title: "Random Title"
      commit_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      assert_equal 1, commit_request.mutations.length
      mutation = commit_request.mutations[0]
      assert_equal :insert, mutation.operation
      assert_equal "albums", mutation.insert.table

      assert_equal 1, mutation.insert.values.length

      # Note that albumid is added at the end as it is automatically calculated when the record is created.
      assert_equal 3, mutation.insert.columns.length
      assert_equal "singerid", mutation.insert.columns[0]
      assert_equal "title", mutation.insert.columns[1]
      assert_equal "albumid", mutation.insert.columns[2]

      assert_equal 3, mutation.insert.values[0].length
      assert_equal singer.singerid, mutation.insert.values[0][0].to_i
      assert_equal "Random Title", mutation.insert.values[0][1]
      assert_equal album.albumid, mutation.insert.values[0][2].to_i
    end

    def test_update_album
      sql_album = "SELECT `albums`.* FROM `albums` WHERE `albums`.`albumid` = @albumid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql_album, TestInterleavedTables::create_random_albums_result(1)
      album = Album.find 1

      album.update title: "New Title"
      commit_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      assert_equal 1, commit_request.mutations.length
      mutation = commit_request.mutations[0]
      assert_equal :update, mutation.operation
      assert_equal "albums", mutation.update.table

      assert_equal 1, mutation.update.values.length

      assert_equal 3, mutation.update.columns.length
      assert_equal "singerid", mutation.update.columns[0]
      assert_equal "albumid", mutation.update.columns[1]
      assert_equal "title", mutation.update.columns[2]

      assert_equal 3, mutation.update.values[0].length
      assert_equal album.singerid, mutation.update.values[0][0].to_i
      assert_equal album.albumid, mutation.update.values[0][1].to_i
      assert_equal "New Title", mutation.update.values[0][2]
    end

    def test_destroy_album
      sql = "SELECT `albums`.* FROM `albums` WHERE `albums`.`albumid` = @albumid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_albums_result(1)
      album = Album.find 1
      album.destroy

      commit_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      refute_nil commit_request
      assert_equal 1, commit_request.mutations.length
      mutation = commit_request.mutations[0]
      assert_equal :delete, mutation.operation
      assert_equal "albums", mutation.delete.table

      assert_equal 1, mutation.delete.key_set.keys.length
      # A delete mutation should use the entire primary key (i.e. singerid, albumid), and it **MUST** be in the correct
      # primary key order, as the column names are not included in the mutation.
      assert_equal 2, mutation.delete.key_set.keys[0].length
      assert_equal album.singerid, mutation.delete.key_set.keys[0][0].to_i
      assert_equal album.albumid, mutation.delete.key_set.keys[0][1].to_i
    end

    def test_select_all_tracks
      sql = "SELECT `tracks`.* FROM `tracks`"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_tracks_result(4)
      Track.all.each do |track|
        refute_nil track.trackid, "trackid should not be nil"
        refute_nil track.albumid, "albumid should not be nil"
        refute_nil track.singerid, "singerid should not be nil"
      end
    end

    def test_find_track
      # Selecting a single album should only use the trackid column, and not the singerid and albumid columns that are
      # technically also part of the primary key.
      sql = "SELECT `tracks`.* FROM `tracks` WHERE `tracks`.`trackid` = @trackid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_tracks_result(1)
      track = Track.find 1
      refute_nil track.trackid, "trackid should not be nil"
      refute_nil track.singerid, "singerid should not be nil"
      refute_nil track.albumid, "albumid should not be nil"
    end

    def test_create_track
      sql = "SELECT `singers`.* FROM `singers` WHERE `singers`.`singerid` = @singerid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_singers_result(1, 1)
      sql = "SELECT `albums`.* FROM `albums` WHERE `albums`.`albumid` = @albumid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_albums_result(1, 1, 1)
      album = Album.find 1

      track = Track.create album: album, title: "Random Title", duration: 5.5
      commit_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      assert_equal 1, commit_request.mutations.length
      mutation = commit_request.mutations[0]
      assert_equal :insert, mutation.operation
      assert_equal "tracks", mutation.insert.table

      assert_equal 1, mutation.insert.values.length

      # Note that trackid is added at the end as it is automatically calculated when the record is created.
      assert_equal 5, mutation.insert.columns.length
      assert_equal "singerid", mutation.insert.columns[0]
      assert_equal "albumid", mutation.insert.columns[1]
      assert_equal "title", mutation.insert.columns[2]
      assert_equal "duration", mutation.insert.columns[3]
      assert_equal "trackid", mutation.insert.columns[4]

      assert_equal 5, mutation.insert.values[0].length
      assert_equal track.singerid, mutation.insert.values[0][0].to_i
      assert_equal track.albumid, mutation.insert.values[0][1].to_i
      assert_equal "Random Title", mutation.insert.values[0][2]
      assert_equal "5.5", mutation.insert.values[0][3]
      assert_equal track.trackid, mutation.insert.values[0][4].to_i
    end

    def test_update_track
      sql_track = "SELECT `tracks`.* FROM `tracks` WHERE `tracks`.`trackid` = @trackid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql_track, TestInterleavedTables::create_random_tracks_result(1, 1, 1, 1)
      track = Track.find 1

      track.update title: "New Title", duration: 3.14
      commit_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      assert_equal 1, commit_request.mutations.length
      mutation = commit_request.mutations[0]
      assert_equal :update, mutation.operation
      assert_equal "tracks", mutation.update.table

      assert_equal 1, mutation.update.values.length

      assert_equal 5, mutation.update.columns.length
      assert_equal "singerid", mutation.update.columns[0]
      assert_equal "albumid", mutation.update.columns[1]
      assert_equal "trackid", mutation.update.columns[2]
      assert_equal "title", mutation.update.columns[3]
      assert_equal "duration", mutation.update.columns[4]

      assert_equal 5, mutation.update.values[0].length
      assert_equal track.singerid, mutation.update.values[0][2].to_i
      assert_equal track.albumid, mutation.update.values[0][2].to_i
      assert_equal track.trackid, mutation.update.values[0][2].to_i
      assert_equal "New Title", mutation.update.values[0][3]
      assert_equal "3.14", mutation.update.values[0][4]
    end

    def test_destroy_track
      sql = "SELECT `tracks`.* FROM `tracks` WHERE `tracks`.`trackid` = @trackid_1 LIMIT @LIMIT_2"
      @mock.put_statement_result sql, TestInterleavedTables::create_random_tracks_result(1, 1, 2, 3)
      track = Track.find 1
      track.destroy

      commit_request = @mock.requests.select { |req| req.is_a?(Google::Cloud::Spanner::V1::CommitRequest) }.first
      refute_nil commit_request
      assert_equal 1, commit_request.mutations.length
      mutation = commit_request.mutations[0]
      assert_equal :delete, mutation.operation
      assert_equal "tracks", mutation.delete.table

      assert_equal 1, mutation.delete.key_set.keys.length
      # A delete mutation should use the entire primary key (i.e. singerid, albumid, trackid), and it **MUST** be in the
      # correct primary key order, as the column names are not included in the mutation.
      assert_equal 3, mutation.delete.key_set.keys[0].length
      assert_equal track.singerid, mutation.delete.key_set.keys[0][0].to_i
      assert_equal track.albumid, mutation.delete.key_set.keys[0][1].to_i
      assert_equal track.trackid, mutation.delete.key_set.keys[0][2].to_i
    end
  end
end
