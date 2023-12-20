# Sample - Query Logs

__NOTE__: Query logs require additional configuration for Cloud Spanner. Please read the entire file.

Rails 7.0 and higher supports [Query Logs](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html). Query Logs
can be used to automatically annotate all queries that are executed based on the current execution context.

The Cloud Spanner ActiveRecord provider can be used in combination with Query Logs. The query logs are automatically
translated to request tags for the queries.
See https://cloud.google.com/spanner/docs/introspection/troubleshooting-with-tags for more 
information about request and transaction tags in Cloud Spanner.

## Configuration
Using Query Logs with Cloud Spanner requires some specific configuration:
1. You must set `ActiveRecord::QueryLogs.prepend_comment = true`
2. You must include `{ request_tag:  "true" }` as the first tag in your configuration.

```ruby
ActiveRecord::QueryLogs.prepend_comment = true
config.active_record.query_log_tags = [
  {
    request_tag:  "true",
  },
  :namespaced_controller,
  :action,
  :job,
  {
    request_id: ->(context) { context[:controller]&.request&.request_id },
    job_id: ->(context) { context[:job]&.job_id },
    tenant_id: -> { Current.tenant&.id },
    static: "value",
  },
]
```

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
