# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class CreateJoinTableTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def setup
        skip_test_table_create!
        super
      end

      def teardown
        connection.ddl_batch do
          %w(artists_musics musics_videos catalog).each do |table_name|
            connection.drop_table table_name, if_exists: true
          end
        end
      end

      def test_create_join_table
        connection.ddl_batch do
          connection.create_join_table :artists, :musics
        end

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      end

      def test_create_join_table_set_not_null_by_default
        connection.ddl_batch do
          connection.create_join_table :artists, :musics
        end

        assert_equal [false, false], connection.columns(:artists_musics).map(&:null)
      end

      def test_create_join_table_with_strings
        connection.ddl_batch do
          connection.create_join_table "artists", "musics"
        end

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      end

      def test_create_join_table_with_symbol_and_string
        connection.ddl_batch do
          connection.create_join_table :artists, "musics"
        end

        assert_equal %w(artist_id music_id), connection.columns(:artists_musics).map(&:name).sort
      end

      def test_create_join_table_with_the_proper_order
        connection.ddl_batch do
          connection.create_join_table :videos, :musics
        end

        assert_equal %w(music_id video_id), connection.columns(:musics_videos).map(&:name).sort
      end

      def test_create_join_table_with_the_table_name
        connection.ddl_batch do
          connection.create_join_table :artists, :musics, table_name: :catalog
        end

        assert_equal %w(artist_id music_id), connection.columns(:catalog).map(&:name).sort
      end

      def test_create_join_table_with_the_table_name_as_string
        connection.ddl_batch do
          connection.create_join_table :artists, :musics, table_name: "catalog"
        end

        assert_equal %w(artist_id music_id), connection.columns(:catalog).map(&:name).sort
      end

      def test_create_join_table_with_column_options
        connection.ddl_batch do
          connection.create_join_table :artists, :musics, column_options: { null: true }
        end

        assert_equal [true, true], connection.columns(:artists_musics).map(&:null)
      end

      def test_create_join_table_without_indexes
        connection.ddl_batch do
          connection.create_join_table :artists, :musics
        end

        assert_predicate connection.indexes(:artists_musics), :blank?
      end

      def test_create_join_table_with_index
        connection.ddl_batch do
          connection.create_join_table :artists, :musics do |t|
            t.index [:artist_id, :music_id]
          end
        end

        assert_equal [%w(artist_id music_id)], connection.indexes(:artists_musics).map(&:columns)
      end

      def test_create_join_table_respects_reference_key_type
        connection.ddl_batch do
          connection.create_join_table :artists, :musics do |t|
            t.references :video
          end
        end

        artist_id, music_id, video_id = connection.columns(:artists_musics).sort_by(&:name)

        assert_equal video_id.sql_type, artist_id.sql_type
        assert_equal video_id.sql_type, music_id.sql_type
      end

      def test_drop_join_table
        connection.ddl_batch do
          connection.create_join_table :artists, :musics
        end
        connection.ddl_batch do
          connection.drop_join_table :artists, :musics
        end

        assert_not connection.table_exists?("artists_musics")
      end

      def test_drop_join_table_with_strings
        connection.ddl_batch do
          connection.create_join_table :artists, :musics
        end
        connection.ddl_batch do
          connection.drop_join_table "artists", "musics"
        end

        assert_not connection.table_exists?("artists_musics")
      end

      def test_drop_join_table_with_the_proper_order
        connection.ddl_batch do
          connection.create_join_table :videos, :musics
        end
        connection.ddl_batch do
          connection.drop_join_table :videos, :musics
        end

        assert_not connection.table_exists?("musics_videos")
      end

      def test_drop_join_table_with_the_table_name
        connection.ddl_batch do
          connection.create_join_table :artists, :musics, table_name: :catalog
        end
        connection.ddl_batch do
          connection.drop_join_table :artists, :musics, table_name: :catalog
        end

        assert_not connection.table_exists?("catalog")
      end

      def test_drop_join_table_with_the_table_name_as_string
        connection.ddl_batch do
          connection.create_join_table :artists, :musics, table_name: "catalog"
        end
        connection.ddl_batch do
          connection.drop_join_table :artists, :musics, table_name: "catalog"
        end

        assert_not connection.table_exists?("catalog")
      end

      def test_drop_join_table_with_column_options
        connection.ddl_batch do
          connection.create_join_table :artists, :musics, column_options: { null: true }
        end
        connection.ddl_batch do
          connection.drop_join_table :artists, :musics, column_options: { null: true }
        end

        assert_not connection.table_exists?("artists_musics")
      end

      def test_create_and_drop_join_table_with_common_prefix
        with_table_cleanup do
          connection.create_join_table "audio_artists", "audio_musics"
          assert connection.table_exists?("audio_artists_musics")

          connection.drop_join_table "audio_artists", "audio_musics"
          assert_not connection.table_exists?("audio_artists_musics"), "Should have dropped join table, but didn't"
        end
      end

      private
      def with_table_cleanup
        tables_before = connection.data_sources

        yield
      ensure
        tables_after = connection.data_sources - tables_before

        connection.ddl_batch do
          tables_after.each do |table|
            connection.drop_table table
          end
        end
      end
    end
  end
end