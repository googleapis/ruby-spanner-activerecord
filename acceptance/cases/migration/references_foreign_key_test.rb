# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ReferencesForeignKeyInCreateTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      def setup
        skip_test_table_create!
        super
        @connection.create_table(:testing_parents, force: true)
      end

      def teardown
        @connection.drop_table "testings", if_exists: true
        @connection.drop_table "testing_parents", if_exists: true
      end

      def test_create_foreign_key_with_table_create
        connection.create_table :testings do |t|
          t.references :testing_parent, foreign_key: true
        end

        fk = connection.foreign_keys("testings").first
        assert_equal "testings", fk.from_table
        assert_equal "testing_parents", fk.to_table
      end

      def test_create_foreign_key_created_by_default
        connection.create_table :testings do |t|
          t.references :testing_parent
        end

        assert_equal [], @connection.foreign_keys("testings")
      end

      def test_options_can_be_passed
        connection.change_table :testing_parents do |t|
          t.references :other, index: { unique: true }
        end
        connection.create_table :testings do |t|
          t.references :testing_parent, foreign_key: { primary_key: :other_id }
        end

        fk = @connection.foreign_keys("testings").find { |k| k.to_table == "testing_parents" }
        assert_equal "other_id", fk.primary_key
      end

      def test_to_table_options_can_be_passed
        @connection.create_table :testings do |t|
          t.references :parent, foreign_key: { to_table: :testing_parents }
        end
        fks = @connection.foreign_keys("testings")
        assert_equal([["testings", "testing_parents", "parent_id"]],
                      fks.map { |fk| [fk.from_table, fk.to_table, fk.column] })
      end
    end
  end
end

module ActiveRecord
  class Migration
    class ReferencesForeignKeyTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper
      include ActiveSupport::Testing::Stream

      def setup
        skip_test_table_create!
        super
        connection = ActiveRecord::Base.connection
        connection.create_table(:testing_parents, force: true)
      end

      def teardown
        connection.drop_table "testings", if_exists: true
        connection.drop_table "testing_parents", if_exists: true
      end

      def test_create_foreign_key_with_changing_table
        connection.create_table :testings
        connection.change_table :testings do |t|
          t.references :testing_parent, foreign_key: true
        end

        fk = connection.foreign_keys("testings").first
        assert_equal "testings", fk.from_table
        assert_equal "testing_parents", fk.to_table
      end

      def test_foreign_key_not_added_by_default_on_table_change
        connection.create_table :testings
        connection.change_table :testings do |t|
          t.references :testing_parent
        end

        assert_equal [], connection.foreign_keys("testings")
      end

      def test_foreign_key_accept_option_on_table_change
        connection.change_table :testing_parents do |t|
          t.references :other, index: { unique: true }
        end
        connection.create_table :testings
        connection.change_table :testings do |t|
          t.references :testing_parent, foreign_key: { primary_key: :other_id }
        end

        fk = connection.foreign_keys("testings").find { |k| k.to_table == "testing_parents" }
        assert_equal "other_id", fk.primary_key
      end

      def test_foreign_key_column_can_be_removed
        connection.create_table :testings do |t|
          t.references :testing_parent, index: true, foreign_key: true
        end

        connection.remove_reference :testings, :testing_parent, foreign_key: true
        assert_equal 0, connection.foreign_keys('testings').size
      end

      def test_remove_column_removes_foreign_key
        connection.create_table :testings do |t|
          t.references :testing_parent, index: true, foreign_key: true
        end

        connection.remove_column :testings, :testing_parent_id
        assert_equal 0, connection.foreign_keys('testings').size
      end

      def test_foreign_key_respect_pluralize_table_names
        original_pluralize_table_names = ActiveRecord::Base.pluralize_table_names
        ActiveRecord::Base.pluralize_table_names = false
        connection.create_table :testing
        connection.change_table :testing_parents do |t|
          t.references :testing, foreign_key: true
        end

        fk = connection.foreign_keys("testing_parents").first
        assert_equal "testing_parents", fk.from_table
        assert_equal "testing", fk.to_table

        assert_difference "@connection.foreign_keys('testing_parents').size", -1 do
          connection.remove_reference :testing_parents, :testing, foreign_key: true
        end
      ensure
        ActiveRecord::Base.pluralize_table_names = original_pluralize_table_names
        connection.drop_table "testing", if_exists: true
      end

      class CreateDogsMigration < ActiveRecord::Migration::Current
        def up
          create_table :dog_owners

          create_table :dogs do |t|
            t.references :dog_owner, foreign_key: true
          end
        end

        def down
          drop_table :dogs, if_exists: true
          drop_table :dog_owners, if_exists: true
        end
      end

      def test_references_foreign_key_with_prefix
        ActiveRecord::Base.table_name_prefix = "p_"
        migration = CreateDogsMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, @connection.foreign_keys("p_dogs").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
        ActiveRecord::Base.table_name_prefix = nil
      end

      def test_references_foreign_key_with_suffix
        ActiveRecord::Base.table_name_suffix = "_s"
        migration = CreateDogsMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal 1, @connection.foreign_keys("dogs_s").size
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
        ActiveRecord::Base.table_name_suffix = nil
      end

      def test_multiple_foreign_keys_can_added_to_same_table
        connection.create_table :testings do |t|
          t.references :parent1, foreign_key: { to_table: :testing_parents }
          t.references :parent2, foreign_key: { to_table: :testing_parents }
        end

        fks = connection.foreign_keys("testings").sort_by(&:column)

        fk_definitions = fks.map { |fk| [fk.from_table, fk.to_table, fk.column] }
        assert_equal([["testings", "testing_parents", "parent1_id"],
                      ["testings", "testing_parents", "parent2_id"]], fk_definitions)
      end

      def test_multiple_foreign_keys_removed
        connection.create_table :testings do |t|
          t.references :parent1, foreign_key: { to_table: :testing_parents }
          t.references :parent2, foreign_key: { to_table: :testing_parents }
        end

        connection.remove_reference :testings, :parent1, foreign_key: { to_table: :testing_parents }

        assert_equal 1, connection.foreign_keys('testings').size

        fks = connection.foreign_keys("testings").sort_by(&:column)

        fk_definitions = fks.map { |fk| [fk.from_table, fk.to_table, fk.column] }
        assert_equal([["testings", "testing_parents", "parent2_id"]], fk_definitions)
      end
    end
  end
end
