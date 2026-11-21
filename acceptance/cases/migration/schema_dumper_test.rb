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

      def is_7_1_or_higher?
        ActiveRecord::gem_version >= Gem::Version.create('7.1.0')
      end

      def is_7_2_or_higher?
        ActiveRecord::gem_version >= Gem::Version.create('7.2.0')
      end

      def pool_or_connection
        if is_7_2_or_higher?
          ActiveRecord::Base.connection_pool
        else
          ActiveRecord::Base.connection
        end
      end

      def test_dump_schema_contains_start_batch_ddl
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("connection.start_batch_ddl")
      end

      def test_dump_schema_contains_run_batch
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("  connection.run_batch\n"\
                                      "rescue\n"\
                                      "  abort_batch\n"\
                                      "  raise")
      end

      def test_dump_schema_contains_albums_table
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        sql = schema.string
        if is_7_1_or_higher?
          assert schema.string.include?("create_table \"albums\", primary_key: [\"singerid\", \"albumid\"]"), sql
        else
          assert schema.string.include?("create_table \"albums\", primary_key: \"albumid\""), sql
        end
      end

      def test_dump_schema_contains_interleaved_index
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("t.index [\"singerid\", \"albumid\", \"title\"], name: \"index_tracks_on_singerid_and_albumid_and_title\", order: { singerid: :asc, albumid: :asc, title: :asc }, null_filtered: true, interleave_in: \"albums\""), schema.string
      end

      def test_dump_schema_should_not_contain_id_limit
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert !schema.string.include?("id: { limit: 8 }")
      end

      def test_dump_schema_contains_commit_timestamp
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert_match(/t\.(datetime|timestamp) "last_updated",.*allow_commit_timestamp: true/, schema.string, schema.string)
      end

      def test_dump_schema_contains_virtual_column
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("t.virtual \"full_name\", type: :string, as: \"COALESCE(first_name || ' ', '') || last_name\", stored: true"), schema.string
      end

      def test_dump_schema_contains_string_array
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("t.string \"col_array_string\", array: true"), schema.string
      end

      def test_dump_schema_index_storing
        connection = pool_or_connection
        schema = StringIO.new
        ActiveRecord::SchemaDumper.dump connection, schema
        assert schema.string.include?("t.index [\"last_name\"], name: \"index_singers_on_last_name\", order: { last_name: :asc }, storing: [\"first_name\", \"tracks_count\"]"), schema.string
      end

      def test_information_schema_parameterized_queries
        info_schema = ActiveRecordSpannerAdapter::Connection.information_schema connector_config.symbolize_keys

        assert_nil info_schema.table("singers' OR '1'='1")
        assert_equal [], info_schema.tables(schema_name: "foo' OR '1'='1")
        assert_equal [], info_schema.table_columns("singers\\")
        assert_equal [], info_schema.table_columns("singers", column_name: "id' OR '1'='1")
        assert_equal [], info_schema.table_primary_keys("singers' OR '1'='1")
        assert_equal ["trackid"], info_schema.table_primary_keys("tracks", false).map(&:name)
        assert_equal [], info_schema.indexes("singers' OR '1'='1", index_name: "idx'\\", index_type: "INDEX")
        assert_equal [], info_schema.indexes("singers", index_type: "INDEX' OR '1'='1")
        assert_equal [], info_schema.index_columns("singers", index_name: "idx' OR '1'='1")
        assert_equal [], info_schema.foreign_keys("singers' OR '1'='1")
        assert_equal [], info_schema.check_constraints("singers' OR '1'='1")

        assert_equal [], info_schema.table_columns(nil)
        assert_equal [], info_schema.table_primary_keys(nil)
        assert_equal [], info_schema.indexes(nil)
        assert_equal [], info_schema.index_columns(nil)
        assert_equal [], info_schema.foreign_keys(nil)
        assert_equal [], info_schema.check_constraints(nil)

        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.create_table :checked_records, force: true do |t|
            t.string :name, null: false
            t.integer :age
            t.check_constraint "age >= 0", name: "chk_checked_records_age"
          end
          check_constraints = info_schema.check_constraints "checked_records"
          assert_equal ["chk_checked_records_age"], check_constraints.map(&:name)
          assert_equal ["age >= 0"], check_constraints.map(&:expression)
        ensure
          conn.drop_table :checked_records, if_exists: true
        end
      end
    end
  end
end
