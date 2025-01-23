# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class ChangeSchemaTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      attr_reader :connection, :table_name

      def setup
        skip_test_table_create!
        super
        @table_name = :testings
      end

      def teardown
        connection.ddl_batch do
          connection.drop_table :testings rescue nil
        end
        ActiveRecord::Base.primary_key_prefix_type = nil
        ActiveRecord::Base.clear_cache!
      end

      def test_add_column
        testing_table_with_only_foo_attribute do
          assert_equal connection.columns(:testings).size, 2
          connection.add_column :testings, :name, :string
          assert_equal connection.columns(:testings).size, 3
        end
      end

      def test_create_table_adds_id
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
        end

        assert_equal %w[id foo].sort, connection.columns(:testings).map(&:name).sort
        assert_equal "id", connection.primary_key(:testings)

        column = connection.columns(:testings).find { |c| c.name == "id" }

        assert_equal "id", column.name
        assert_equal :integer, column.type
      end

      def test_create_table_with_custom_primary_key
        connection.ddl_batch do
          connection.create_table :testings, force: true, primary_key: :email do |t|
            t.string :name
          end
        end

        assert_equal "email", connection.primary_key(:testings)
      end

      def test_create_table_with_custom_primary_key_using_options
        connection.ddl_batch do
          connection.create_table :testings, force: true, id: false do |t|
            t.string :phone, primary_key: true
            t.string :name
          end
        end

        assert_equal "phone", connection.primary_key(:testings)
      end

      def test_create_table_with_custom_primary_key_using_type
        connection.ddl_batch do
          connection.create_table :testings, force: true, id: false do |t|
            t.primary_key :username, limit: 255
            t.string :name
          end
        end

        assert_equal "username", connection.primary_key(:testings)

        column = connection.columns(:testings).find { |c| c.name == "username" }

        assert_equal "username", column.name
        assert_equal :integer, column.type
      end

      def test_create_table_with_custom_primary_key_type
        connection.ddl_batch do
          connection.create_table :testings, force: true, id: false do |t|
            t.primary_key :user_id, :integer
            t.string :name
          end
        end

        assert_equal "user_id", connection.primary_key(:testings)

        column = connection.columns(:testings).find { |c| c.name == "user_id" }

        assert_equal "user_id", column.name
        assert_equal :integer, column.type
      end

      def test_create_table_with_not_null_column
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string, null: false
          end
        end

        assert_raises ActiveRecord::StatementInvalid do
          connection.transaction {
            connection.execute "insert into testings (id, foo) values (#{generate_id}, NULL)"
          }
        end
      end

      def test_create_table_with_column_default
        testings_klass = Class.new ActiveRecord::Base
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.string :name, null: false, default: "no name"
            t.integer :age, null: false, default: 10
          end
          testings_klass.table_name = "testings"
        end

        testings_klass.reset_column_information
        assert_equal false, testings_klass.columns_hash["name"].null
        assert_equal false, testings_klass.columns_hash["age"].null

        assert_nothing_raised {
          testings_klass.connection.transaction {
            testings_klass.connection.execute("insert into testings (id, name, age) values (#{generate_id}, DEFAULT, DEFAULT)")
          }
        }
      end

      def test_create_table_with_limits
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string, limit: 255
            t.column :default_int, :integer
          end
        end

        columns = connection.columns :testings
        foo = columns.detect { |c| c.name == "foo" }
        assert_equal "STRING(255)", foo.sql_type
        assert_equal 255, foo.limit

        default_int = columns.detect { |c| c.name == "default_int" }
        assert_equal "INT64", default_int.sql_type
      end

      def test_create_table_with_primary_key_prefix_as_table_name_with_underscore
        ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore

        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
        end

        assert_equal "testing_id", connection.primary_key(:testings)

        columns = connection.columns(:testings)
        assert_equal %w[testing_id foo].sort, columns.map(&:name).sort
      end

      def test_create_table_with_primary_key_prefix_as_table_name
        ActiveRecord::Base.primary_key_prefix_type = :table_name

        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
        end

        assert_equal "testingid", connection.primary_key(:testings)

        columns = connection.columns(:testings)
        assert_equal %w[testingid foo].sort, columns.map(&:name).sort
      end

      def test_create_table_raises_when_redefining_primary_key_column
        error = assert_raise ArgumentError do
          connection.ddl_batch do
            connection.create_table :testings do |t|
              t.column :id, :string
            end
          end
        end
        expected = if ActiveRecord::gem_version < Gem::Version.create('7.1.0')
          "you can't redefine the primary key column 'id'. To define a custom primary key, pass { id: false } to create_table."
        else
          "you can't redefine the primary key column 'id' on 'testings'. To define a custom primary key, pass { id: false } to create_table."
        end


        assert_equal expected, error.message
      end

      def test_create_table_raises_when_redefining_custom_primary_key_column
        error = assert_raise ArgumentError do
          connection.ddl_batch do
            connection.create_table :testings, primary_key: :testing_id do |t|
              t.column :testing_id, :string
            end
          end
        end

        expected = if ActiveRecord::gem_version < Gem::Version.create('7.1.0')
          "you can't redefine the primary key column 'testing_id'. To define a custom primary key, pass { id: false } to create_table."
        else
          "you can't redefine the primary key column 'testing_id' on 'testings'. To define a custom primary key, pass { id: false } to create_table."
        end
        assert_equal expected, error.message
      end

      def test_create_table_raises_when_defining_existing_column
        error = assert_raise ArgumentError do
          connection.ddl_batch do
            connection.create_table :testings do |t|
              t.column :testing_column, :string
              t.column :testing_column, :integer
            end
          end
        end

        expected = if ActiveRecord::gem_version < Gem::Version.create('7.1.0')
          "you can't define an already defined column 'testing_column'."
        else
          "you can't define an already defined column 'testing_column' on 'testings'."
        end
        assert_equal expected, error.message
      end

      def test_create_table_with_timestamps_should_create_datetime_columns
        connection.ddl_batch do
          connection.create_table table_name do |t|
            t.timestamps
          end
        end
        created_columns = connection.columns table_name

        created_at_column = created_columns.detect { |c| c.name == "created_at" }
        updated_at_column = created_columns.detect { |c| c.name == "updated_at" }

        assert_not created_at_column.null
        assert_not updated_at_column.null
      end

      def test_create_table_with_timestamps_should_create_datetime_columns_with_options
        connection.ddl_batch do
          connection.create_table table_name do |t|
            t.timestamps null: true
          end
        end
        created_columns = connection.columns table_name

        created_at_column = created_columns.detect { |c| c.name == "created_at" }
        updated_at_column = created_columns.detect { |c| c.name == "updated_at" }

        assert created_at_column.null
        assert updated_at_column.null
      end

      def test_create_table_without_a_block
        connection.create_table table_name
      end

      def test_add_column_not_null_without_default
        skip "Unimplemented error: Cannot add NOT NULL column to existing table"
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
          connection.add_column :testings, :bar, :string, null: false
        end

        assert_raise ActiveRecord::NotNullViolation do
          connection.transaction {
            connection.execute "insert into testings (id, foo, bar) values (#{generate_id}, 'hello', NULL)"
          }
        end
      end

      def test_add_column_with_timestamp_type
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :timestamp
          end
        end

        column = connection.columns(:testings).find { |c| c.name == "foo" }

        assert_equal :time, column.type
        assert_equal "TIMESTAMP", column.sql_type
      end

      def test_change_column_quotes_column_names
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :select, :string
          end
        end
        # These two changes cannot be in one batch, as the change_column operation will check whether the column
        # actually exists before executing any DDL statements.
        connection.ddl_batch do
          connection.change_column :testings, :select, :string, limit: 10
        end

        connection.transaction {
          connection.execute "insert into testings (#{connection.quote_column_name 'id'},"\
            "#{connection.quote_column_name 'select'}) values (#{generate_id}, '7 chars')"
        }
      end

      def test_keeping_notnull_constraints_on_change
        person_klass = Class.new ActiveRecord::Base
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :title, :string
          end
          person_klass.table_name = "testings"
          person_klass.connection.add_column "testings", "wealth", :integer, null: false
        end

        person_klass.reset_column_information
        assert_equal false, person_klass.columns_hash["wealth"].null

        assert_nothing_raised {
          person_klass.connection.transaction {
            person_klass.connection.execute("insert into testings (id, title, wealth) values (#{generate_id}, 'tester', 100000)")
          }
        }

        # change column, make it nullable
        connection.ddl_batch do
          person_klass.connection.change_column "testings", "wealth", :integer, null: true
        end
        person_klass.reset_column_information
        assert_nil person_klass.columns_hash["wealth"].default
        assert_equal true, person_klass.columns_hash["wealth"].null
      end

      def test_change_column_null
        testing_table_with_only_foo_attribute do
          notnull_migration = Class.new(ActiveRecord::Migration::Current) do
            def change
              change_column_null :testings, :foo, false
            end
          end
          notnull_migration.new.suppress_messages do
            notnull_migration.migrate(:up)
            assert_equal false, connection.columns(:testings).find { |c| c.name == "foo" }.null
            notnull_migration.migrate(:down)
            assert connection.columns(:testings).find { |c| c.name == "foo" }.null
          end
        end
      end

      def test_column_exists
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
        end

        assert connection.column_exists?(:testings, :foo)
        assert_not connection.column_exists?(:testings, :bar)
      end

      def test_column_exists_with_type
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
            t.column :bar, :float
          end
        end

        assert connection.column_exists?(:testings, :foo, :string)
        assert_not connection.column_exists?(:testings, :foo, :integer)

        assert connection.column_exists?(:testings, :bar, :float)
        assert_not connection.column_exists?(:testings, :bar, :integer)
      end

      def test_column_exists_with_definition
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string, limit: 100
            t.column :bar, :float
            t.column :taggable_id, :integer, null: false
            t.column :taggable_type, :string
          end
        end

        assert connection.column_exists?(:testings, :foo, :string, limit: 100)
        assert_not connection.column_exists?(:testings, :foo, :string, limit: nil)
        assert connection.column_exists?(:testings, :bar, :float)
        assert connection.column_exists?(:testings, :taggable_id, :integer, null: false)
        assert_not connection.column_exists?(:testings, :taggable_id, :integer, null: true)
        assert connection.column_exists?(:testings, :taggable_type, :string, default: nil)
      end

      def test_column_exists_on_table_with_no_options_parameter_supplied
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.string :foo
          end
        end
        connection.change_table :testings do |t|
          assert t.column_exists?(:foo)
          assert_not (t.column_exists?(:bar))
        end
      end

      def test_drop_table_if_exists
        connection.ddl_batch do
          connection.create_table(:testings)
        end
        assert connection.table_exists?(:testings)
        connection.ddl_batch do
          connection.drop_table(:testings, if_exists: true)
        end
        assert_not connection.table_exists?(:testings)
      end

      def test_drop_table_if_exists_nothing_raised
        assert_nothing_raised { connection.drop_table(:nonexistent, if_exists: true) }
      end

      def test_drop_and_create_table_with_indexes
        connection.ddl_batch do
          connection.create_table :testings, force: true do |t|
            t.string :name, index: true
          end
        end

        assert_nothing_raised {
          connection.create_table :testings, force: true do |t|
            t.string :name, index: true
          end
        }

        assert_equal true, connection.table_exists?(:testings)
        assert_equal true, connection.index_exists?(:testings, :name)
      end

      private

      def testing_table_with_only_foo_attribute
        connection.ddl_batch do
          connection.create_table :testings do |t|
            t.column :foo, :string
          end
        end

        yield
      end
    end
  end
end