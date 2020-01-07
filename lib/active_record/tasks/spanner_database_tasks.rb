require "google/cloud/spanner"

module ActiveRecord
  module Tasks
    class SpannerDatabaseTasks
      attr_reader :config

      def initialize config
        @config = config.symbolize_keys
        @config[:client_config] = @config[:client_config]&.symbolize_keys
      end

      def create
        job = spanner.create_database config[:instance], config[:database]
        job.wait_until_done!
        raise Google::Cloud::Error.from_error job.error if job.error?
      rescue Google::Cloud::Error => error
        if error.instance_of? Google::Cloud::AlreadyExistsError
          raise ActiveRecord::Tasks::DatabaseAlreadyExists
        end

        raise ActiveRecord::StatementInvalid, error
      end

      def drop
        database.drop
      end

      def purge
        drop
        create
      end

      def charset
        config[:charset]
      end

      def collation
        config[:collation]
      end

      def structure_dump filename, _
        file = File.open filename, "w"
        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables

        database.ddl.each do |statement|
          next if ignore_tables.any? { statement.include? "TABLE #{table}" }

          file.write statement
          file.write "\n"
        end
      ensure
        file.close
      end

      def structure_load filename, _
        statements = File.read(filename).split(/(?=^CREATE)/)
        job = database.update statements: statements
        job.wait_until_done!
        raise Google::Cloud::Error.from_error job.error if job.error?
      end

      private

      def spanner
        @spanner ||= Google::Cloud.spanner \
          config[:project],
          config[:credentials],
          scope: config[:scope],
          timeout: config[:timeout],
          client_config: config[:client_config]
      end

      def database
        database = spanner.database config[:instance], config[:database]
        return database if database
        raise ActiveRecord::NoDatabaseError
      end
    end
  end
end
