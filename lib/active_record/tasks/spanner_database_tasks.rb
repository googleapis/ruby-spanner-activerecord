require "spanner_activerecord/service"

module ActiveRecord
  module Tasks
    class SpannerDatabaseTasks
      def initialize config
        config = config.symbolize_keys
        @service = SpannerActiverecord::Service.new(
          config[:project],
          config[:instance],
          config[:database],
          credentials: config[:credentials],
          scope: config[:scope],
          timeout: config[:timeout],
          client_config: config[:client_config]
        )
      end

      def create
        @service.create_database
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
        @service.database
      rescue Google::Cloud::NotFoundError => error
        raise ActiveRecord::NoDatabaseError, error
      end
    end
  end
end
