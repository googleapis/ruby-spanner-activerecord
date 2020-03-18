gem "minitest"
require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"
require "active_support"
require "google/cloud/spanner"
require "active_record"
require "spanner_activerecord"
require "securerandom"

# rubocop:disable Style/GlobalVars

$spanner_test_database = "ar-test-#{SecureRandom.hex 4}"

def connector_config
  {
    "adapter" => "spanner",
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
  $spanner_instance ||= spanner.instance ENV["SPANNER_TEST_INSTANCE"]
end

def create_test_database
  job = spanner_instance.create_database $spanner_test_database
  job.wait_until_done!
  unless job.error?
    puts "'#{$spanner_test_database}' test db created."
    return
  end

  raise "Error in creating database. Error code#{job.error.message}"
end

def drop_test_database
  spanner_instance.database($spanner_test_database)&.drop

  puts "#{$spanner_test_database} database deleted"
end

module Acceptance
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
        @skip_test_table_create
      end

      def teardown
        TestModel.reset_table_name
        connection.drop_table :test_models, if_exists: true

        super
      end

      def uuid
        "'#{SecureRandom.uuid}'"
      end

      delegate *CONNECTION_METHODS, to: :connection
    end
  end
end

Minitest.after_run do
  drop_test_database
end

create_test_database

# rubocop:enable Style/GlobalVars
