# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"

module ActiveRecord
  module Model
    class InterleaveTest
      class WithPartialInsertsDisabledTest < SpannerAdapter::TestCase
        include SpannerAdapter::Associations::TestHelper

        class Singer < ActiveRecord::Base
          has_many :albums, foreign_key: :singerid, dependent: :delete_all
          has_many :tracks, foreign_key: :singerid
        end

        class Album < ActiveRecord::Base
          self.primary_keys = :singerid, :albumid

          belongs_to :singer, foreign_key: :singerid

          if ActiveRecord::VERSION::MAJOR >= 7
            self.partial_inserts = false
          end
        end

        attr_accessor :singer

        def setup
          super

          @singer = Singer.create first_name: "FirstName", last_name: "LastName"
        end

        def teardown
          Album.destroy_all
          Singer.destroy_all
        end

        def test_with_partial_inserts_disabled
          Album.create! title: "Title3", singer: singer
        end
      end

      class StringParentKeyTest < SpannerAdapter::TestCase
        include TestHelpers::WithSeparateDatabase

        class Singer < ActiveRecord::Base
          has_many :albums, foreign_key: :singer_id
        end

        class Album < ActiveRecord::Base
          self.primary_keys = [:singer_id, :album_id]
          belongs_to :singer, foreign_key: :singer_id
        end

        def setup
          super

          connection.ddl_batch do
            connection.create_table :singers, id: false do |t|
              t.string :singer_id, limit: 36, primary_key: true, null: false
              t.string :name, null: false
            end

            connection.create_table :albums, id: false do |t|
              t.interleave_in :singers
              t.string :singer_id, limit: 36, parent_key: true, primary_key: true, null: false
              t.integer :album_id, primary_key: true, null: false
              t.string :title, null: false
            end
          end
        end

        def test_create_album
          singer = Singer.create!(id: SecureRandom.uuid, name: "a singer")
          Album.create!(singer: singer, title: "an album")
        end
      end
    end
  end
end
