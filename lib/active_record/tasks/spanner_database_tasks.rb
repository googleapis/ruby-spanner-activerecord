require "spanner_activerecord/connection"

module ActiveRecord
  module Tasks
    class SpannerDatabaseTasks
      attr_reader :config

      def initialize config
        @config = config.symbolize_keys
        @connection = SpannerActiverecord::Connection.new \
          @config[:project],
          @config[:instance],
          @config[:database],
          credentials: @config[:credentials],
          scope: @config[:scope],
          timeout: @config[:timeout],
          client_config: @config[:client_config]
      end

      def create
        @connection.create_database
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

      def structure_dump filename, _extra_flags
        file = File.open filename, "w"
        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables

        if ignore_tables.any?
          index_regx = /^CREATE(.*)INDEX(.*)ON (#{ignore_tables.join "|"})\(/
          table_regx = /^CREATE TABLE (#{ignore_tables.join "|"})/
        end

        database.ddl(force: true).each do |statement|
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
        database.update statements: statements
      end

      private

      def database
        @connection.database
      rescue Google::Cloud::NotFoundError => error
        raise ActiveRecord::NoDatabaseError, error
      end
    end
  end
end
