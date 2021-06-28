# Sample - Array Data Type

This example shows how to use the `ARRAY` data type with the Spanner ActiveRecord adapter. The sample uses a single
table that has one column for each possible `ARRAY` data type:

```sql
CREATE TABLE entity_with_array_types (
    id INT64 NOT NULL,
    col_array_string ARRAY<STRING(MAX)>,
    col_array_int64 ARRAY<INT64>,
    col_array_float64 ARRAY<FLOAT64>,
    col_array_numeric ARRAY<NUMERIC>,
    col_array_bool ARRAY<BOOL>,
    col_array_bytes ARRAY<BYTES(MAX)>,
    col_array_date ARRAY<DATE>,
    col_array_timestamp ARRAY<TIMESTAMP>,
) PRIMARY KEY (id);
```

This schema is created in ActiveRecord as follows:

```ruby
create_table :entity_with_array_types do |t|
  # Create a table with a column with each possible array type.
  t.column :col_array_string, :string, array: true
  t.column :col_array_int64, :bigint, array: true
  t.column :col_array_float64, :float, array: true
  t.column :col_array_numeric, :numeric, array: true
  t.column :col_array_bool, :boolean, array: true
  t.column :col_array_bytes, :binary, array: true
  t.column :col_array_date, :date, array: true
  t.column :col_array_timestamp, :datetime, array: true
end
```

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the command

```bash
bundle exec rake run
```
