# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "active_record/tasks/spanner_database_tasks"

# TODO: Delete this patch after https://github.com/rails/rails/pull/46747 is merged
#       or Spanner Adapter patches this on itself.
module ActiveRecord::ConnectionAdapters::SchemaStatements
  def assume_migrated_upto_version(version)
    version = version.to_i
    sm_table = quote_table_name(schema_migration.table_name)

    migrated = migration_context.get_all_versions
    versions = migration_context.migrations.map(&:version)

    execute "INSERT INTO #{sm_table} (version) VALUES (#{quote(version.to_s)})" unless migrated.include?(version)

    inserting = (versions - migrated).select { |v| v < version }
    if inserting.any?
      if (duplicate = inserting.detect { |v| inserting.count(v) > 1 })
        raise "Duplicate migration #{duplicate}. Please renumber your migrations to resolve the conflict."
      end

      execute insert_versions_sql(inserting)
    end
  end

  def insert_versions_sql(versions)
    sm_table = quote_table_name(schema_migration.table_name)

    if versions.is_a?(Array)
      sql = +"INSERT INTO #{sm_table} (version) VALUES\n"
      sql << versions.reverse.map { |v| "(#{quote(v.to_s)})" }.join(",\n")
      sql << ';'
      sql
    else
      "INSERT INTO #{sm_table} (version) VALUES (#{quote(versions.to_s)});"
    end
  end
end

module ActiveRecord
  module Tasks
    class DatabaseTasksTest < SpannerAdapter::TestCase
      attr_reader :connector_config, :connection

      def setup
        @database_id = "ar-tasks-test-#{SecureRandom.hex 4}"
        @connector_config = {
          "adapter" => "spanner",
          "emulator_host" => ENV["SPANNER_EMULATOR_HOST"],
          "project" => ENV["SPANNER_TEST_PROJECT"],
          "instance" => ENV["SPANNER_TEST_INSTANCE"],
          "credentials" => ENV["SPANNER_TEST_KEYFILE"],
          "database" => @database_id
        }

        create_database
        ActiveRecord::Base.establish_connection connector_config
        @connection = ActiveRecord::Base.connection

        begin
          @original_db_dir = ActiveRecord::Tasks::DatabaseTasks.db_dir
          @original_env = ActiveRecord::Tasks::DatabaseTasks.env
        rescue NameError
          # ignore `NameError: uninitialized constant primary::Rails`
        end

        db_dir = File.expand_path "./db", __dir__
        ActiveRecord::Tasks::DatabaseTasks.db_dir = db_dir
        FileUtils.mkdir db_dir

        ActiveRecord::Tasks::DatabaseTasks.env = "test"
      end

      def teardown
        ActiveRecord::Base.connection_pool.disconnect!
        FileUtils.rm_rf ActiveRecord::Tasks::DatabaseTasks.db_dir
        ActiveRecord::Tasks::DatabaseTasks.db_dir = @original_db_dir
        ActiveRecord::Tasks::DatabaseTasks.env = @original_env
      end

      def create_database
        job = spanner_instance.create_database @database_id
        job.wait_until_done!
        if job.error?
          raise "Error in creating database. Error code#{job.error.message}"
        end
      end

      def drop_database
        ActiveRecord::Base.connection_pool.disconnect!
        spanner_instance.database(@database_id)&.drop
      end

      def test_structure_dump_and_load
        ActiveRecord::Schema.define(version: 1) do
          create_table :tasks_table do |t|
            t.string :body
          end
        end

        db_config =
          if ActiveRecord.version >= Gem::Version.new("6.1")
            ActiveRecord::DatabaseConfigurations::HashConfig.new "test",
                                                                 "primary",
                                                                 connector_config
          else
            connector_config
          end

        tables = connection.tables.sort
        ActiveRecord::Tasks::DatabaseTasks.dump_schema db_config, :sql
        drop_database
        create_database
        ActiveRecord::Tasks::DatabaseTasks.load_schema db_config, :sql
        assert_equal tables, connection.tables.sort
      end
    end
  end
end
