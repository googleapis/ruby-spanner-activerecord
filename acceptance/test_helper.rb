gem "minitest"
require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"
require "active_support"
require "google/cloud/spanner"
require "active_record"
require "active_support/testing/stream"
require "activerecord_spanner_adapter"
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

def current_adapter? *names
  names.include? :SpannerAdapter
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

      def uuid
        "'#{SecureRandom.uuid}'"
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
          t.boolean :active
          t.binary :file
          t.binary :data, limit: 255
          t.date :start_date
          t.datetime :start_datetime
          t.time :start_time
        end
      end

      def teardown
        super
        TestTypeModel.delete_all
      end
    end
  end
end

Minitest.after_run do
  drop_test_database
end

create_test_database

# rubocop:enable Style/GlobalVars
