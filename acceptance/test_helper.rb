# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

gem "minitest"
require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"
require "active_support"
require "google/cloud/spanner"
require "active_record"
require "active_support/testing/stream"
require "activerecord-spanner-adapter"
require "active_record/connection_adapters/spanner_adapter"
require "securerandom"
require "composite_primary_keys" if ActiveRecord::gem_version < Gem::Version.create('7.1.0')

# rubocop:disable Style/GlobalVars

$spanner_test_database = "ar-test-#{SecureRandom.hex 4}"

def connector_config
  {
    "adapter" => "spanner",
    "emulator_host" => ENV["SPANNER_EMULATOR_HOST"],
    "project" => ENV["SPANNER_TEST_PROJECT"],
    "instance" => ENV["SPANNER_TEST_INSTANCE"],
    "credentials" => ENV["SPANNER_TEST_KEYFILE"],
    "database" => $spanner_test_database
  }
end

def spanner
  $spanner ||= Google::Cloud::Spanner.new(
    project_id: ENV["SPANNER_TEST_PROJECT"],
    credentials: ENV["SPANNER_TEST_KEYFILE"]
  )
end

def spanner_instance
  unless spanner.instance ENV["SPANNER_TEST_INSTANCE"]
    config = ENV["SPANNER_EMULATOR_HOST"] ? "emulator-config" : "regional-us-central1"
    puts "Creating test instance #{ENV["SPANNER_TEST_INSTANCE"]} with config #{config}"
    job = spanner.create_instance ENV["SPANNER_TEST_INSTANCE"],
                                  name:   "ActiveRecord Test Instance",
                                  config: config,
                                  nodes:  1
    job.wait_until_done!
    $owned_test_instance = true
  end
  $spanner_instance ||= spanner.instance ENV["SPANNER_TEST_INSTANCE"]
end

def create_test_database
  job = spanner_instance.create_database $spanner_test_database
  job.wait_until_done!
  if job.error?
    raise "Error in creating database. Error code#{job.error.message}"
  end

  puts "'#{$spanner_test_database}' test db created."

  puts "Loading test schema..."
  ActiveRecord::Base.establish_connection connector_config
  require_relative "schema/schema"
  create_tables_in_test_schema
end

def drop_test_database
  ActiveRecord::Base.connection_pool.disconnect!
  spanner_instance&.delete if $owned_test_instance
  spanner_instance.database($spanner_test_database)&.drop unless $owned_test_instance

  puts "Test instance #{spanner_instance} deleted" if $owned_test_instance
  puts "#{$spanner_test_database} database deleted" unless $owned_test_instance
end

def current_adapter? *names
  names.include? :SpannerAdapter
end

def load_test_schema
  ActiveRecord::Base.establish_connection connector_config

  require_relative "schema/schema"
  create_tables_in_test_schema
end

module SpannerAdapter
  class TestCase < ActiveSupport::TestCase
    def assert_column(model, column_name, msg = nil)
      assert has_column?(model, column_name), msg
    end

    def assert_no_column(model, column_name, msg = nil)
      assert_not has_column?(model, column_name), msg
    end

    def has_column?(model, column_name)
      model.reset_column_information
      model.column_names.include?(column_name.to_s)
    end

    def capture_sql
      ActiveRecord::Base.connection.materialize_transactions
      SQLCounter.clear_log
      yield
      SQLCounter.log.dup
    end

    def assert_queries(num = 1, options = {})
      ignore_none = options.fetch(:ignore_none) { num == :any }
      ActiveRecord::Base.connection.materialize_transactions
      SQLCounter.clear_log
      x = yield
      the_log = ignore_none ? SQLCounter.log_all : SQLCounter.log
      if num == :any
        assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
      else
        mesg = "#{the_log.size} instead of #{num} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
        assert_equal num, the_log.size, mesg
      end
      x
    end

    def assert_no_queries(options = {}, &block)
      options.reverse_merge! ignore_none: true
      assert_queries(0, options, &block)
    end
  end

  module Migration
    module TestHelper
      attr_accessor :connection

      CONNECTION_METHODS = %w[
        add_column remove_column rename_column add_index change_column
        rename_table column_exists? index_exists?
        add_reference add_belongs_to remove_reference remove_references
        remove_belongs_to change_column_default
      ].freeze

      class TestModel < ActiveRecord::Base
        self.table_name = :test_models
      end

      def setup
        ActiveRecord::Base.establish_connection connector_config
        @connection = ActiveRecord::Base.connection

        unless @skip_test_table_create
          connection.create_table :test_models do |t|
            t.timestamps null: true
          end

          TestModel.reset_column_information
        end
        super
      end

      def skip_test_table_create!
        @skip_test_table_create = true
      end

      def teardown
        TestModel.reset_table_name

        unless @skip_test_table_create
          connection.drop_table :test_models, if_exists: true
        end

        super
      end

      def generate_id
        connection.next_sequence_value nil
      end

      delegate *CONNECTION_METHODS, to: :connection
    end
  end

  module Types
    module TestHelper
      attr_accessor :connection

      class TestTypeModel < ActiveRecord::Base
        self.table_name = :test_types
      end

      def setup
        super

        ActiveRecord::Base.establish_connection connector_config
        @connection = ActiveRecord::Base.connection

        return if connection.table_exists? :test_types

        connection.create_table :test_types do |t|
          t.string :name, limit: 255
          t.string :description
          t.text :bio
          t.integer :length
          t.float :weight
          t.numeric :price
          t.boolean :active
          t.binary :file
          t.binary :data, limit: 255
          t.date :start_date
          t.datetime :start_datetime
          t.time :start_time
          t.json :details
        end
      end

      def teardown
        super
        TestTypeModel.delete_all
      end
    end
  end

  module Associations
    module TestHelper
      def setup
        ActiveRecord::Base.establish_connection connector_config
        @connection = ActiveRecord::Base.connection
      end
    end
  end

  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :log_all

      def clear_log
        self.log = []
        self.log_all = []
      end
    end

    clear_log

    def call(name, start, finish, message_id, values)
      return if values[:cached]

      sql = values[:sql]
      self.class.log_all << sql
      self.class.log << sql unless ["SCHEMA", "TRANSACTION"].include? values[:name]
    end
  end

  ActiveSupport::Notifications.subscribe("sql.active_record", SQLCounter.new)
end

Minitest.after_run do
  drop_test_database
end

create_test_database

# rubocop:enable Style/GlobalVars
