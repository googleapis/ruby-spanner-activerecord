# Sample - Bit-reversed Sequence

This example shows how to use a bit-reversed sequence to generate the primary key of a model.

See https://cloud.google.com/spanner/docs/primary-key-default-value#bit-reversed-sequence for more information
about bit-reversed sequences in Cloud Spanner.

## Requirements
Using bit-reversed sequences for generating primary key values in ActiveRecord has the following requirements:
1. You must use __ActiveRecord version 7.1 or higher__.
2. Your models must include a sequence name like this: `self.sequence_name = :singer_sequence`
3. You must create the bit-reversed sequence using a SQL statement in your migrations.

## Creating Tables with Bit-Reversed Sequences in ActiveRecord
You can create bit-reversed sequences using migrations in ActiveRecord by executing a SQL statement using the underlying
connection.

```ruby
connection.execute "create sequence singer_sequence OPTIONS (sequence_kind = 'bit_reversed_positive')"
```

The sequence can be used to generate a default value for the primary key column of a table:

```ruby
create_table :singers, id: false do |t|
  t.integer :singerid, primary_key: true, null: false, default: -> { "GET_NEXT_SEQUENCE_VALUE(SEQUENCE singer_sequence)" }
  t.string :first_name
  t.string :last_name
end
```

## Example Data Model
This example uses the following table schema:

```sql
CREATE SEQUENCE singer_sequence (OPTIONS sequence_kind="bit_reversed_positive")

CREATE TABLE singers (
    singerid INT64 NOT NULL DEFAULT GET_NEXT_SEQUENCE_VALUE(SEQUENCE singer_sequence),
    first_name STRING(MAX),
    last_name STRING(MAX)
) PRIMARY KEY (singerid);

CREATE TABLE albums (
    singerid INT64 NOT NULL,
    albumid INT64 NOT NULL,
    title STRING(MAX)
) PRIMARY KEY (singerid, albumid), INTERLEAVE IN PARENT singers;
```

This schema can be created in ActiveRecord 7.1 and later as follows:

```ruby
# Execute the entire migration as one DDL batch.
connection.ddl_batch do
  connection.execute "create sequence singer_sequence OPTIONS (sequence_kind = 'bit_reversed_positive')"
  
  # Explicitly define the primary key.
  create_table :singers, id: false, primary_key: :singerid do |t|
    t.integer :singerid, primary_key: true, null: false, default: -> { "GET_NEXT_SEQUENCE_VALUE(SEQUENCE singer_sequence)" } 
    t.string :first_name
    t.string :last_name
  end

  create_table :albums, primary_key: [:singerid, :albumid], id: false do |t|
    # Interleave the `albums` table in the parent table `singers`.
    t.interleave_in :singers
    t.integer :singerid
    t.integer :albumid
    t.string :title
  end
end
```

## Models for Tables with a Sequence
The models for tables that use a sequence to generate the primary key must include the sequence name. This instructs
the Cloud Spanner ActiveRecord provider to let the database generate the primary key value, instead of generating one
in memory.

### Example Models

```ruby
class Singer < ActiveRecord::Base
  self.sequence_name = :singer_sequence
  
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  has_many :albums, foreign_key: :singerid
end

class Album < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: :singerid
end
```

## Running the Sample

The sample will automatically start a Spanner Emulator in a docker container and execute the sample
against that emulator. The emulator will automatically be stopped when the application finishes.

Run the application with the following commands:

```bash
export AR_VERSION="~> 7.1.2"
bundle install
bundle exec rake run
```
