# Sample - Generated Columns

This example shows how to use generated columns with the Spanner ActiveRecord adapter.

See https://cloud.google.com/spanner/docs/generated-column/how-to for more information on generated columns.

This example uses the following table schema:

```sql
CREATE TABLE singers (
    id         INT64 NOT NULL,
    first_name STRING(100),
    last_name  STRING(200) NOT NULL,
    full_name  STRING(300) NOT NULL AS (COALESCE(first_name || ' ', '') || last_name) STORED,
) PRIMARY KEY (id);
```

This schema can be created in ActiveRecord as follows:

```ruby
create_table :singers do |t|
  t.string :first_name, limit: 100
  t.string :last_name, limit: 200, null: false
  t.string :full_name, limit: 300, null: false, as: "COALESCE(first_name || ' ', '') || last_name", stored: true
end
```

The `full_name` attribute will automatically be set by Cloud Spanner, and it is not allowed to set a value for the
attribute when creating a record in ActiveRecord, or to update the value of an existing record. Instead, only the
`first_name` and `last_name` attributes should be set.

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
