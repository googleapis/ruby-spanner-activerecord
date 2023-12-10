# Sample - Interleaved Tables

__NOTE__: This example requires Rails 7.1 or later.

This example shows how to use interleaved tables with the Spanner ActiveRecord adapter in Rails 7.1 and later.
Interleaved tables use composite primary keys. This is only supported by Rails 7.1 and later. For older versions,
you need to use the third-party gem `composite_primary_key` (https://github.com/composite-primary-keys/composite_primary_keys).

See https://cloud.google.com/spanner/docs/schema-and-data-model#creating-interleaved-tables for more information
on interleaved tables if you are not familiar with this concept.

## Creating Interleaved Tables in ActiveRecord
You can create interleaved tables using migrations in ActiveRecord by using the following Spanner ActiveRecord specific
methods that are defined on `TableDefinition`:
* `interleave_in`: Specifies which parent table a child table should be interleaved in and optionally whether
  deletes of a parent record should automatically cascade delete all child records.

Cloud Spanner requires a child table to include the exact same primary key columns as the parent table in addition to
the primary key column(s) of the child table. This means that the default `id` primary key column of ActiveRecord is
not usable in combination with interleaved tables. Instead each primary key column should be prefixed with the table
name of the table that it references, or use some other unique name.

## Example Data Model
This example uses the following table schema:

```sql
CREATE TABLE singers (
    singerid INT64 NOT NULL,
    first_name STRING(MAX),
    last_name STRING(MAX)
) PRIMARY KEY (singerid);

CREATE TABLE albums (
    singerid INT64 NOT NULL,
    albumid INT64 NOT NULL,
    title STRING(MAX)
) PRIMARY KEY (singerid, albumid), INTERLEAVE IN PARENT singers;

CREATE TABLE tracks (
    singerid INT64 NOT NULL,
    albumid INT64 NOT NULL,
    trackid INT64 NOT NULL,
    title STRING(MAX),
    duration NUMERIC
) PRIMARY KEY (singerid, albumid, trackid), INTERLEAVE IN PARENT albums ON DELETE CASCADE;
```

This schema can be created in ActiveRecord 7.1 and later as follows:

```ruby
# Execute the entire migration as one DDL batch.
connection.ddl_batch do
  # Explicitly define the primary key.
  create_table :singers, id: false, primary_key: :singerid do |t|
    t.integer :singerid
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

  create_table :tracks, primary_key: [:singerid, :albumid, :trackid], id: false do |t|
    # Interleave the `tracks` table in the parent table `albums` and cascade delete all tracks that belong to an
    # album when an album is deleted.
    t.interleave_in :albums, :cascade
    t.integer :singerid
    t.integer :albumid
    t.integer :trackid
    t.string :title
    t.numeric :duration
  end
end
```

## Models for Interleaved Tables
An interleaved table parent/child relationship can be modelled as a `belongs_to`/`has_many` association in
ActiveRecord. As the columns that are used to reference a parent record use a custom column name, it is required to also
include the custom column name(s) in the `belongs_to` and `has_many` definitions.

Instances of these models can be used in the same way as any other association in ActiveRecord, but with a couple of
inherent limitations:
* It is not possible to change the parent record of a child record. For instance, changing the singer of an album in the
  above example is impossible, as Cloud Spanner does not allow such an update.
* It is not possible to de-reference a parent record by setting it to null.
* It is only possible to delete a parent record with existing child records, if the child records are also deleted. This
  can be done by enabling ON DELETE CASCADE in Cloud Spanner, or by deleting the child records using ActiveRecord.

### Example Models

```ruby
class Singer < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  has_many :albums, foreign_key: :singerid

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `tracks` is [`singerid`, `albumid`, `trackid`].
  # The `singerid` column can be used to associate tracks with a singer without the need to go through albums.
  # Note also that the inclusion of `singerid` as a column in `tracks` is required in order to make `tracks` a child
  # table of `albums` which has primary key (`singerid`, `albumid`).
  has_many :tracks, foreign_key: :singerid
end

class Album < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: :singerid

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  # Rails 7.1 requires using query_constraints to define a composite foreign key.
  has_many :tracks, query_constraints: [:singerid, :albumid]
end

class Track < ActiveRecord::Base
  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  # Rails 7.1 requires a composite primary key in a belongs_to relationship to be specified as query_constraints.
  belongs_to :album, query_constraints: [:singerid, :albumid]

  # `tracks` also has a `singerid` column that can be used to associate a Track with a Singer.
  belongs_to :singer, foreign_key: :singerid

  # Override the default initialize method to automatically set the singer attribute when an album is given.
  def initialize attributes = nil
    super
    self.singer ||= album&.singer
  end

  def album=value
    super
    # Ensure the singer of this track is equal to the singer of the album that is set.
    self.singer = value&.singer
  end
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
