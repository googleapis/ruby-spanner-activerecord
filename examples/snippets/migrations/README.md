# Sample - Migrations

This example shows the best way to execute migrations with the Spanner ActiveRecord adapter.

It is [strongly recommended](https://cloud.google.com/spanner/docs/schema-updates#best-practices) that you limit the
frequency of schema updates in Cloud Spanner, and that schema changes are batched together whenever possible. The
Spanner ActiveRecord adapter supports batching DDL statements together using the `connection.ddl_batch` method. This
method accepts a block of DDL statements that will be sent to Cloud Spanner as one batch. It is recommended that
migrations are grouped together in one or in a limited number of batches for optimal performance.

This example shows how to create three tables in one batch:

```ruby
# Execute the entire migration as one DDL batch.
connection.ddl_batch do
  create_table :singers do |t|
    t.string :first_name
    t.string :last_name
  end

  create_table :albums do |t|
    t.string :title
    t.references :singers
  end

  create_table :tracks do |t|
    t.string :title
    t.numeric :duration
    t.references :albums
  end
end
```

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
