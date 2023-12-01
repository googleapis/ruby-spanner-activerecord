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
  module Associations
    class HasManyUsingInterleavedTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :singer, :album1, :album2

      def setup
        super
        @original_verbosity = $VERBOSE
        $VERBOSE = nil

        @singer = Singer.create first_name: "FirstName1", last_name: "LastName1"

        @album2 = Album.create title: "Title2", singer: singer
        @album1 = Album.create title: "Title1", singer: singer

        @track2_1 = Track.create title: "Title2_1", album: album2, duration: 3.6
        @track2_2 = Track.create title: "Title2_2", album: album2, duration: 3.3
        @track1_1 = Track.create title: "Title1_1", album: album1, duration: 4.5
        @track1_2 = Track.create title: "Title1_2", album: album1
      end

      def teardown
        Album.destroy_all
        Singer.destroy_all

        $VERBOSE = @original_verbosity
      end

      def test_has_many
        assert_equal 2, singer.albums.count
        assert_equal singer.albums.pluck(:title).sort, %w[Title1 Title2]

        assert_equal 4, singer.tracks.count
        assert_equal singer.tracks.pluck(:title).sort, %w[Title1_1 Title1_2 Title2_1 Title2_2]

        assert_equal 2, album1.tracks.count
        assert_equal album1.tracks.pluck(:title).sort, %w[Title1_1 Title1_2]
        assert_equal 2, album2.tracks.count
        assert_equal album2.tracks.pluck(:title).sort, %w[Title2_1 Title2_2]
      end

      def test_finding_using_associated_fields
        assert_equal Album.where(singerid: singer.id).to_a, singer.albums.to_a
        assert_equal Track.where(singerid: singer.id).to_a, singer.tracks.to_a
      end

      def test_successful_build_association
        album = singer.albums.build title: "New Title"
        assert album.save

        singer.reload
        assert_equal album, singer.albums.find(album.id)
      end

      def test_successful_build_nested_association
        track = album1.tracks.build title: "New Title", duration: 4.45
        assert track.save

        album1.reload
        assert_equal track, album1.tracks.find(track.id)
      end

      def test_create_and_destroy_associated_records
        singer2 = Singer.new first_name: "First", last_name: "Last"
        singer2.albums.build title: "New Title 1", albumid: Album.next_sequence_value
        singer2.albums.build title: "New Title 2", albumid: Album.next_sequence_value
        singer2.save!

        singer2.reload

        assert_equal 2, singer2.albums.count
        assert_equal 4, Album.count

        singer2.albums.destroy_all
        singer2.reload

        assert_equal 0, singer2.albums.count
        assert_equal 2, Album.count
      end

      def test_create_and_destroy_nested_associated_records
        album3 = Album.new singer: singer, title: "Title 3"
        album3.tracks.build title: "Title3_1", duration: 2.5, singer: singer, trackid: Track.next_sequence_value
        album3.tracks.build title: "Title3_2", singer: singer, trackid: Track.next_sequence_value
        album3.save!

        album3.reload

        assert_equal 2, album3.tracks.count
        assert_equal 6, singer.tracks.count
        assert_equal 6, Track.count

        album3.tracks.destroy_all
        album3.reload

        assert_equal 0, album3.tracks.count
        assert_equal 4, Track.count
      end

      def test_create_and_delete_associated_records
        singer2 = Singer.new first_name: "First", last_name: "Last"
        singer2.albums.build title: "Album - 11", albumid: Album.next_sequence_value
        singer2.albums.build title: "Album - 12", albumid: Album.next_sequence_value
        singer2.save!

        singer2.reload

        assert_equal 2, singer2.albums.count
        assert_equal 4, Album.count

        assert_equal 2, singer2.albums.delete_all
        singer2.reload

        assert_equal 0, singer2.albums.count
        assert_equal 2, Album.count
      end

      def test_create_and_delete_nested_associated_records
        album3 = Album.new title: "Album 3", singer: singer
        album3.tracks.build title: "Track - 31", singer: singer, trackid: Track.next_sequence_value
        album3.tracks.build title: "Track - 32", singer: singer, trackid: Track.next_sequence_value
        album3.save!

        album3.reload

        assert_equal 2, album3.tracks.count
        assert_equal 6, Track.count

        assert_equal 2, album3.tracks.delete_all
        album3.reload

        assert_equal 0, album3.tracks.count
        assert_equal 4, Track.count
      end

      def test_update_associated_records
        count = singer.albums.update_all title: "Title - Update"
        assert_equal singer.albums.count, count

        singer.reload
        singer.albums.each do |album|
          assert_equal "Title - Update", album.title
        end
      end

      def test_update_nested_associated_records
        count = album1.tracks.update_all title: "Title - Update", duration: 6.626
        assert_equal album1.tracks.count, count

        album1.reload
        album1.tracks.each do |track|
          assert_equal "Title - Update", track.title
          assert_equal 6.626, track.duration
        end
      end

      def test_fetch_associated_record_with_order
        albums = singer.albums.order title: :desc
        assert_equal %w[Title2 Title1], albums.pluck(:title)

        albums = singer.albums.order title: :asc
        assert_equal %w[Title1 Title2], albums.pluck(:title)
      end

      def test_fetch_nested_associated_record_with_order
        tracks = album1.tracks.order duration: :desc
        assert_equal [4.5, nil], tracks.pluck(:duration)

        tracks = album1.tracks.order duration: :asc
        assert_equal [nil, 4.5], tracks.pluck(:duration)
      end

      def test_set_counter_cache
        singer.tracks.create! title: "New Title 1", album: album1
        singer.tracks.create! title: "New Title 2", album: album2

        singer.reload
        assert_equal 6, singer.tracks_count
      end

      def test_cascade_destroy
        assert_equal 4, singer.tracks.count

        assert album1.destroy

        singer.reload
        assert_equal 2, singer.tracks.count
      end

      def test_cascade_delete
        assert_equal 4, singer.tracks.count

        assert album1.delete

        singer.reload
        assert_equal 2, singer.tracks.count
      end
    end
  end
end