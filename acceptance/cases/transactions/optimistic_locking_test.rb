# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

# ActiveRecord 7.1 introduced native support for composite primary keys.
# This deprecates the https://github.com/composite-primary-keys/composite_primary_keys gem that was previously used in
# this library to support composite primary keys, which again are needed for interleaved tables. These tests use the
# third-party composite primary key gem and are therefore not executed for Rails 7.1 and higher.
return if ActiveRecord::gem_version >= Gem::Version.create('7.1.0')

require "test_helper"
require "models/singer"
require "models/album"
require "models/track"

module ActiveRecord
  module Transactions
    class OptimisticLockingTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      def setup
        super

        @original_verbosity = $VERBOSE
        $VERBOSE = nil

        singer = Singer.create first_name: "Pete", last_name: "Allison"
        album = Album.create title: "Musical Jeans", singer: singer
        Track.create title: "Increased Headline", album: album, singer: singer
      end

      def teardown
        super

        Track.delete_all
        Album.delete_all
        Singer.delete_all

        $VERBOSE = @original_verbosity
      end

      # Runs the given block in a transaction with the given isolation level, or without a transaction if isolation is
      # nil.
      def run_in_transaction isolation
        if isolation
          Base.transaction isolation: isolation do
            yield
          end
        else
          yield
        end
      end

      def test_update_single_record_increases_version_number
        [nil, :serializable, :buffered_mutations].each do |isolation|
          singer = Singer.all.sample
          original_version = singer.lock_version

          run_in_transaction isolation do
            singer.update last_name: "Peterson-#{singer.last_name}"
          end

          singer.reload
          assert_equal original_version + 1, singer.lock_version
        end
      end

      def test_update_multiple_records_increases_version_numbers
        singer = Singer.all.sample
        album = Album.all.sample
        track = Track.all.sample
        [nil, :serializable, :buffered_mutations].each do |isolation|
          original_singer_version = singer.reload.lock_version
          original_album_version = album.reload.lock_version
          original_track_version = track.reload.lock_version

          run_in_transaction isolation do
            singer.update last_name: "Peterson-#{singer.last_name}"
            singer.albums.each { |album| album.update title: "Updated: #{album.title}" }
            singer.tracks.each { |track| track.update title: "Updated: #{track.title}" }
          end

          singer.reload
          assert_equal original_singer_version + 1, singer.lock_version
          singer.albums.each { |album| assert_equal original_album_version + 1, album.lock_version }
          singer.tracks.each { |track| assert_equal original_track_version + 1, track.lock_version }
        end
      end

      def test_concurrent_update_single_record_fails
        [nil, :serializable, :buffered_mutations].each do |isolation|
          singer = Singer.all.sample
          original_version = singer.lock_version

          # Update the singer in a separate thread to simulate a concurrent update.
          t = Thread.new do
            singer2 = Singer.find singer.id
            singer2.update last_name: "Henderson-#{singer2.last_name}"
          end
          t.join

          run_in_transaction isolation do
            assert_raises ActiveRecord::StaleObjectError do
              singer.update last_name: "Peterson-#{singer.last_name}"
            end
          end

          singer.reload
          assert_equal original_version + 1, singer.lock_version
          assert singer.last_name.start_with?("Henderson-")
        end
      end

      def test_concurrent_update_multiple_records_fails
        singer = Singer.all.sample
        album = Album.all.sample
        track = Track.all.sample
        [nil, :serializable, :buffered_mutations].each do |isolation|
          original_singer_version = singer.reload.lock_version
          original_album_version = album.reload.lock_version
          original_track_version = track.reload.lock_version

          # Update the singer in a separate thread to simulate a concurrent update.
          t = Thread.new do
            singer2 = Singer.find singer.id
            singer2.update last_name: "Henderson-#{singer2.last_name}"
          end
          t.join

          run_in_transaction isolation do
            assert_raises ActiveRecord::StaleObjectError do
              singer.update last_name: "Peterson-#{singer.last_name}"
            end
            singer.albums.each { |album| album.update title: "Updated: #{album.title}" }
            singer.tracks.each { |track| track.update title: "Updated: #{track.title}" }
          end

          singer.reload
          # The singer should be updated, but only by the separate thread.
          assert_equal original_singer_version + 1, singer.lock_version
          assert singer.last_name.start_with? "Henderson-"
          singer.albums.each { |album| assert_equal original_album_version + 1, album.lock_version }
          singer.tracks.each { |track| assert_equal original_track_version + 1, track.lock_version }
        end
      end
    end
  end
end
