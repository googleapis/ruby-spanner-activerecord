# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/singer"
require "models/album_partial_disabled"

module ActiveRecord
  module Model
    class InterleaveTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

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
        AlbumPartialDisabled.create! title: "Title3", singer: singer
      end
    end
  end
end
