# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class IndexTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def test_dump_schema_contains_albums_table
        connection = ActiveRecord::Base.connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("create_table \"albums\", primary_key: \"albumid\"")
      end

      def test_dump_schema_contains_interleaved_index
        connection = ActiveRecord::Base.connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("t.index [\"singerid\", \"albumid\", \"title\"], name: \"index_tracks_on_singerid_and_albumid_and_title\", order: { singerid: :asc, albumid: :asc, title: :asc }, null_filtered: true, interleave_in: \"albums\""), schema.string
      end
    end
  end
end
