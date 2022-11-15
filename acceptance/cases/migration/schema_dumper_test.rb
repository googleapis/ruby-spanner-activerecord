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

      def test_dump_schema_contains_start_batch_ddl
        connection = ActiveRecord::Base.connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("connection.start_batch_ddl")
      end

      def test_dump_schema_contains_run_batch
        connection = ActiveRecord::Base.connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("  connection.run_batch\n"\
                                      "rescue\n"\
                                      "  abort_batch\n"\
                                      "  raise")
      end
    end
  end
end
