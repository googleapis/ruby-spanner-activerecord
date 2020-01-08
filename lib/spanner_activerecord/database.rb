module SpannerActiverecord
  class Database
    def initialize spanner_database
      @spanner_database = spanner_database
    end

    def database_id
      @spanner_database.database_id
    end

    def instance_id
      @spanner_database.instance_id
    end

    # @params [Array<String>, String] sql Single or list of statements
    def update statements, wait_until_done: true
      job = @spanner_database.update statements: Array(statements)
      job.wait_until_done! if wait_until_done
      raise Google::Cloud::Error.from_error job.error if job.error?
      job
    end

    def drop
      @spanner_database.drop
    end

    def ddl force: nil
      @spanner_database.ddl force: force
    end
  end
end
