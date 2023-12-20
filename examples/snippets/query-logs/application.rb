# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"
require_relative "models/singer"
require_relative "models/album"

class Application
  def self.run
    enable_query_logs

    puts ""
    puts "Query all Albums and include an automatically generated request tag"
    albums = Album.all
    puts "Queried #{albums.length} albums using an automatically generated request tag"

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end

  def self.enable_query_logs
    # Enables Query Logs in a non-Rails application. Normally, this should be done
    # as described here: https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html
    ActiveRecord.query_transformers << ActiveRecord::QueryLogs

    # Query log comments *MUST* be prepended to be included as a request tag.
    ActiveRecord::QueryLogs.prepend_comment = true

    # This block manually enables Query Logs without a full Rails application.
    # This should normally not be needed in your application.
    ActiveRecord::QueryLogs.taggings.merge!(
      application:  "example-app",
      action:       "run-test-application",
      pid:          -> { Process.pid.to_s },
      socket:       ->(context) { context[:connection].pool.db_config.socket },
      db_host:      ->(context) { context[:connection].pool.db_config.host },
      database:     ->(context) { context[:connection].pool.db_config.database }
    )

    ActiveRecord::QueryLogs.tags = [
      # The first tag *MUST* be the fixed value 'request_tag:true'.
      {
        request_tag:  "true"
      },
      :controller,
      :action,
      :job,
      {
        request_id: ->(context) { context[:controller]&.request&.request_id },
        job_id: ->(context) { context[:job]&.job_id }
      },
      :db_host,
      :database
    ]
  end
end

Application.run
