# Sample - Isolation Level

This example shows how to use a specific isolation level for read/write transactions
using the Spanner ActiveRecord adapter.

You can specify the isolation level in two ways:

1. Set a default in the database configuration:

```yaml
development:
  adapter: spanner
  emulator_host: localhost:9010
  project: test-project
  instance: test-instance
  database: testdb
  isolation_level: :serializable,
  pool: 5
  timeout: 5000
  schema_dump: false
```

2. Specify the isolation level for a specific transaction. This will override any
   default that is set in the database configuration.

```ruby
ActiveRecord::Base.transaction isolation: :repeatable_read do
  # Execute transaction code...
end
```

The sample will automatically start a Spanner Emulator in a Docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
