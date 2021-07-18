# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ForeignKeyTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper
      include ActiveSupport::Testing::Stream

      class Rocket < ActiveRecord::Base
      end

      class Astronaut < ActiveRecord::Base
      end

      def setup
        skip_test_table_create!
        super

        connection.ddl_batch do
          connection.create_table "rockets", force: true do |t|
            t.string :name
          end

          connection.create_table "astronauts", force: true do |t|
            t.string :name
            t.references :rocket
          end
        end
      end

      def teardown
        connection.ddl_batch do
          connection.drop_table "astronauts", if_exists: true
          connection.drop_table "rockets", if_exists: true
          connection.drop_table "fk_test_has_fk", if_exists: true
          connection.drop_table "fk_test_has_pk", if_exists: true
        end
      end

      def test_foreign_keys
        connection.ddl_batch do
          connection.create_table :fk_test_has_pk, primary_key: "pk_id", force: :cascade do |t|
          end

          connection.create_table :fk_test_has_fk, force: true do |t|
            t.references :fk, null: false
            t.foreign_key :fk_test_has_pk, column: "fk_id", name: "fk_name", primary_key: "pk_id"
          end
        end

        foreign_keys = connection.foreign_keys("fk_test_has_fk")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "fk_test_has_fk", fk.from_table
        assert_equal "fk_test_has_pk", fk.to_table
        assert_equal "fk_id", fk.column
        assert_equal "pk_id", fk.primary_key
      end

      def test_add_foreign_key_inferes_column
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets
        end

        foreign_keys = connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "astronauts", fk.from_table
        assert_equal "rockets", fk.to_table
        assert_equal "rocket_id", fk.column
        assert_equal "id", fk.primary_key
      end

      def test_add_foreign_key_with_column
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"
        end

        foreign_keys = connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "astronauts", fk.from_table
        assert_equal "rockets", fk.to_table
        assert_equal "rocket_id", fk.column
        assert_equal "id", fk.primary_key
      end

      def test_add_foreign_key_with_non_standard_primary_key
        connection.ddl_batch do
          connection.create_table :space_shuttles, id: false, force: true do |t|
            t.integer :pk, primary_key: true
          end

          connection.add_foreign_key(:astronauts, :space_shuttles,
            column: "rocket_id", primary_key: "pk", name: "custom_pk")
        end

        foreign_keys = connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "astronauts", fk.from_table
        assert_equal "space_shuttles", fk.to_table
        assert_equal "pk", fk.primary_key
      ensure
        connection.ddl_batch do
          connection.remove_foreign_key :astronauts, name: "custom_pk", to_table: "space_shuttles"
          connection.drop_table :space_shuttles
        end
      end

      def test_foreign_key_exists
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets
        end

        assert connection.foreign_key_exists?(:astronauts, :rockets)
        assert_not connection.foreign_key_exists?(:astronauts, :stars)
      end

      def test_foreign_key_exists_by_column
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"
        end

        assert connection.foreign_key_exists?(:astronauts, column: "rocket_id")
        assert_not connection.foreign_key_exists?(:astronauts, column: "star_id")
      end

      def test_foreign_key_exists_by_name
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"
        end

        assert connection.foreign_key_exists?(:astronauts, name: "fancy_named_fk")
        assert_not connection.foreign_key_exists?(:astronauts, name: "other_fancy_named_fk")
      end

      def test_foreign_key_exists_in_change_table
        connection.change_table(:astronauts) do |t|
          t.foreign_key :rockets, column: "rocket_id", name: "fancy_named_fk"

          assert t.foreign_key_exists?(column: "rocket_id")
          assert_not t.foreign_key_exists?(column: "star_id")
        end
      end

      def test_remove_foreign_key_inferes_column
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets
        end

        assert_equal 1, connection.foreign_keys("astronauts").size
        connection.ddl_batch do
          @connection.remove_foreign_key :astronauts, :rockets
        end
        assert_equal [], connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_key_by_column
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"
        end

        assert_equal 1, connection.foreign_keys("astronauts").size
        connection.ddl_batch do
          @connection.remove_foreign_key :astronauts, column: "rocket_id"
        end
        assert_equal [], connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_key_by_symbol_column
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets, column: :rocket_id
        end

        assert_equal 1, connection.foreign_keys("astronauts").size
        connection.ddl_batch do
          connection.remove_foreign_key :astronauts, column: :rocket_id
        end
        assert_equal [], connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_key_by_name
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"
        end

        assert_equal 1, connection.foreign_keys("astronauts").size
        connection.ddl_batch do
          connection.remove_foreign_key :astronauts, name: "fancy_named_fk"
        end
        assert_equal [], connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_non_existing_foreign_key_raises
        e = assert_raises ArgumentError do
          connection.remove_foreign_key :astronauts, :rockets
        end
        assert_equal "Table 'astronauts' has no foreign key for rockets", e.message
      end

      def test_remove_foreign_key_by_the_select_one_on_the_same_table
        connection.ddl_batch do
          connection.add_foreign_key :astronauts, :rockets
          connection.add_reference :astronauts, :myrocket, foreign_key: { to_table: :rockets }
        end

        assert_equal 2, connection.foreign_keys("astronauts").size

        connection.ddl_batch do
          connection.remove_foreign_key :astronauts, :rockets, column: "myrocket_id"
        end

        assert_equal [["astronauts", "rockets", "rocket_id"]],
          connection.foreign_keys("astronauts").map { |fk| [fk.from_table, fk.to_table, fk.column] }
      end

      class CreateCitiesAndHousesMigration < ActiveRecord::Migration::Current
        def change
          connection.ddl_batch do
            create_table("cities") { |t| }

            create_table("houses") do |t|
              t.references :city
            end
            add_foreign_key :houses, :cities, column: "city_id"
          end

          # remove and re-add to test that schema is updated and not accidentally cached
          remove_foreign_key :houses, :cities
          add_foreign_key :houses, :cities, column: "city_id"
        end
      end

      def test_add_foreign_key_is_reversible
        migration = CreateCitiesAndHousesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, connection.foreign_keys("houses").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
      end

      class CreateSchoolsAndClassesMigration < ActiveRecord::Migration::Current
        def up
          connection.ddl_batch do
            create_table(:schools)

            create_table(:classes) do |t|
              t.references :school
            end
            add_foreign_key :classes, :schools
          end
        end

        def down
          connection.ddl_batch do
            drop_table :classes, if_exists: true
            drop_table :schools, if_exists: true
          end
        end
      end

      def test_add_foreign_key_with_prefix
        ActiveRecord::Base.table_name_prefix = "p_"
        migration = CreateSchoolsAndClassesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, connection.foreign_keys("p_classes").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
        ActiveRecord::Base.table_name_prefix = nil
      end

      def test_add_foreign_key_with_suffix
        ActiveRecord::Base.table_name_suffix = "_s"
        migration = CreateSchoolsAndClassesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, connection.foreign_keys("classes_s").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
        ActiveRecord::Base.table_name_suffix = nil
      end
    end
  end
end

