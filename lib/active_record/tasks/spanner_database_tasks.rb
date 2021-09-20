# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "active_record/connection_adapters/spanner_adapter"

module ActiveRecord
  module Tasks
    class SpannerDatabaseTasks
      def initialize config
        config = config.symbolize_keys
        @connection = ActiveRecordSpannerAdapter::Connection.new config
      end

      def create
        @connection.create_database
      rescue Google::Cloud::Error => error
        if error.instance_of? Google::Cloud::AlreadyExistsError
          raise ActiveRecord::DatabaseAlreadyExists
        end

        raise error
      end

      def drop
        @connection.database.drop
      end

      def purge
        drop
        create
      end

      def charset
        nil
      end

      def collation
        nil
      end

      def structure_dump filename, _extra_flags
        file = File.open filename, "w"
        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables

        if ignore_tables.any?
          index_regx = /^CREATE(.*)INDEX(.*)ON (#{ignore_tables.join "|"})\(/
          table_regx = /^CREATE TABLE (#{ignore_tables.join "|"})/
        end

        @connection.database.ddl(force: true).each do |statement|
          next if ignore_tables.any? &&
                  (table_regx =~ statement || index_regx =~ statement)
          file.write statement
          file.write "\n"
        end
      ensure
        file.close
      end

      def structure_load filename, _extra_flags
        statements = File.read(filename).split(/(?=^CREATE)/)
        @connection.execute_ddl statements
      end
    end

    DatabaseTasks.register_task(
      /spanner/,
      "ActiveRecord::Tasks::SpannerDatabaseTasks"
    )
  end
end
