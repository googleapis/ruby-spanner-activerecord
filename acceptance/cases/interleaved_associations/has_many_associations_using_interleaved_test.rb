# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/singer"
require "models/album"
require "models/track"

module ActiveRecord
  module Associations
    class HasManyUsingInterleavedTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :singer

      def setup
        super

        @singer = Singer.create first_name: "FirstName1", last_name: "LastName1"

        Album.create title: "Title2", singer: singer
        Album.create title: "Title1", singer: singer
      end

      def teardown
        Album.destroy_all
        Singer.destroy_all
      end

      def test_has_many
        assert_equal 2, singer.albums.count
        assert_equal singer.albums.pluck(:title).sort, %w[Title1 Title2]
      end
    end
  end
end