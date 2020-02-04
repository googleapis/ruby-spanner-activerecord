require "securerandom"
require "google/cloud/spanner"
require "spanner_client_ext"
require "spanner_activerecord/information_schema"
require "spanner_activerecord/connection"

module SpannerActiverecord
  class Service
    attr_reader :spanner

    def initialize \
        project_id,
        instance_id,
        database_id,
        credentials: nil,
        scope: nil,
        timeout: nil,
        client_config: nil
      @instance_id = instance_id
      @database_id = database_id
      @spanner = Google::Cloud.spanner(
        project_id,
        credentials,
        scope: scope,
        timeout: timeout,
        client_config: client_config&.symbolize_keys
      )
    end

    def self.services config
      config = config.symbolize_keys
      @services ||= {}
      path = "#{config[:project]}/#{config[:instance]}/#{config[:database]}"
      @services[path] ||= Service.new(
        config[:project],
        config[:instance],
        config[:database],
        credentials: config[:credentials],
        scope: config[:scope],
        timeout: config[:timeout],
        client_config: config[:client_config]
      )
    end

    def new_connection
      Connection.new self, @spanner.create_session(@instance_id, @database_id)
    end

    # Database Operations

    # @params [Array<String>, String] sql Single or list of statements
    def execute_ddl statements, operation_id: nil, wait_until_done: true
      job = database.update statements: statements, operation_id: operation_id
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.done?
    end

    def create_database
      job = @spanner.create_database @instance_id, @database_id
      job.wait_until_done!
      raise Google::Cloud::Error.from_error job.error if job.error?
      job.database
    end

    def database
      @database ||= begin
        database = @spanner.database @instance_id, @database_id
        raise Google::Cloud::NotFoundError, @database_id unless database
        database
      end
    end
  end
end
