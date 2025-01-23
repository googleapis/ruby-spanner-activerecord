# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "securerandom"

require "active_record/tasks/spanner_database_tasks"

module TestHelpers
  module WithSeparateDatabase
    attr_reader :connection

    def setup
      spanner_adapter_connection.create_database
      ActiveRecord::Base.establish_connection connection_config
      @connection = ActiveRecord::Base.connection
    end

    def teardown
      spanner_adapter_connection.database.drop
      ActiveRecord::Base.connection_pool.disconnect!
    end

    def connection_config
      {
        "adapter" => "spanner",
        "emulator_host" => ENV["SPANNER_EMULATOR_HOST"],
        "project" => ENV["SPANNER_TEST_PROJECT"],
        "instance" => ENV["SPANNER_TEST_INSTANCE"],
        "credentials" => ENV["SPANNER_TEST_KEYFILE"],
        "database" => database_id,
      }
    end

    def database_id
      @database_id ||= "ar-test-#{SecureRandom.hex 4}"
    end

    def spanner_adapter_connection
      @spanner_adapter_connection ||=
        ActiveRecordSpannerAdapter::Connection.new(
          connection_config.symbolize_keys
        )
    end
  end
end
