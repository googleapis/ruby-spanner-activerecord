# Sample - Interleaved Tables

This example shows how to use interleaved tables with the Spanner ActiveRecord adapter.

See https://cloud.google.com/spanner/docs/schema-and-data-model#creating-interleaved-tables for more information
on interleaved tables if you are not familiar with this concept.

## Creating Interleaved Tables in ActiveRecord
You can create interleaved tables using migrations in ActiveRecord by using the following Spanner ActiveRecord specific
methods that are defined on `TableDefinition`:
* `interleave_in`: Specifies which parent table a child table should be interleaved in and optionally whether
  deletes of a parent record should automatically cascade delete all child records. 
* `parent_key`: Creates a column that is a reference to (a part of) the primary key of the parent table. Each child
  table must include all the primary key columns of the parent table as a `parent_key`.

Cloud Spanner requires a child table to include the exact same primary key columns as the parent table in addition to
the primary key column(s) of the child table. This means that the default `id` primary key column of ActiveRecord is
not usable in combination with interleaved tables. Instead each primary key column should be prefixed with the table
name of the table that it references, or use some other unique name.

## Performance Recommendations
ActiveRecord will only use the child id when it access a record in a child table. The primary key of the child table is
however the combination of both the parent and the child id, and selecting a child record using only the child id can
cause a full table scan of the child table, as the primary key is not usable for the query. It is therefore
__strongly recommended__ that you also create a unique index on the child id column. See also the example data model
below.

## Example Data Model
This example uses the following table schema:

```sql
CREATE TABLE singers (
    singerid INT64 NOT NULL,
    first_name STRING(MAX),
    last_name STRING(MAX)
) PRIMARY KEY (singerid);

CREATE TABLE albums (
    albumid INT64 NOT NULL,
    singerid INT64 NOT NULL,
    title STRING(MAX)
) PRIMARY KEY (singerid, albumid), INTERLEAVE IN PARENT singers;

CREATE UNIQUE INDEX index_albums_on_albumid ON albums (albumid);

CREATE TABLE tracks (
    trackid INT64 NOT NULL,
    singerid INT64 NOT NULL,
    albumid INT64 NOT NULL,
    title STRING(MAX),
    duration NUMERIC
) PRIMARY KEY (singerid, albumid, trackid), INTERLEAVE IN PARENT albums ON DELETE CASCADE;

CREATE UNIQUE INDEX index_tracks_on_trackid ON tracks (trackid);
```

This schema can be created in ActiveRecord as follows:

```ruby
create_table :singers, id: false do |t|
    # Explicitly define the primary key with a custom name to prevent all primary key columns from being named `id`.
    t.primary_key :singerid
    t.string :first_name
    t.string :last_name
end

create_table :albums, id: false do |t|
    # Interleave the `albums` table in the parent table `singers`.
    t.interleave_in :singers
    t.primary_key :albumid
    # `singerid` is defined as a `parent_key` which makes it a part of the primary key in the table definition, but
    # it is not presented to ActiveRecord as part of the primary key, to prevent ActiveRecord from considering this
    # to be an entity with a composite primary key (which is not supported by ActiveRecord).
    t.parent_key :singerid
    t.string :title
end

# Add a unique index to the albumid column to prevent full table scans when a single album record is queried.
add_index :albums, [:albumid], unique: true

create_table :tracks, id: false do |t|
    # Interleave the `tracks` table in the parent table `albums` and cascade delete all tracks that belong to an
    # album when an album is deleted.
    t.interleave_in :albums, :cascade
    # `trackid` is considered the only primary key column by ActiveRecord.
    t.primary_key :trackid
    # `singerid` and `albumid` form the parent key of `tracks`. These are part of the primary key definition in the
    # database, but are presented as parent keys to ActiveRecord.
    t.parent_key :singerid
    t.parent_key :albumid
    t.string :title
    t.numeric :duration
end

# Add a unique index to the trackid column to prevent full table scans when a single track record is queried.
add_index :tracks, [:trackid], unique: true
```

## Models for Interleaved Tables
An interleaved table parent/child relationship must be modelled as a `belongs_to`/`has_many` association in
ActiveRecord. As the columns that are used to reference a parent record use a custom column name, it is required to also
include the custom column name in the `belongs_to` and `has_many` definitions.

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
  # `albums` is defined as INTERLEAVE IN PARENT `singers`. The primary key of `albums` is (`singerid`, `albumid`), but
  # only `albumid` is used by ActiveRecord as the primary key. The `singerid` column is defined as a `parent_key` of
  # `albums` (see also the `db/migrate/01_create_tables.rb` file).
  has_many :albums, foreign_key: "singerid"

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`. The primary key of `tracks` is
  # (`singerid`, `albumid`, `trackid`), but only `trackid` is used by ActiveRecord as the primary key. The `singerid`
  # and `albumid` columns are defined as `parent_key` of `tracks` (see also the `db/migrate/01_create_tables.rb` file).
  # The `singerid` column can therefore be used to associate tracks with a singer without the need to go through albums.
  # Note also that the inclusion of `singerid` as a column in `tracks` is required in order to make `tracks` a child
  # table of `albums` which has primary key (`singerid`, `albumid`).
  has_many :tracks, foreign_key: "singerid"
end

class Album < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`. The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: "singerid"

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`. The primary key of `albums` is (`singerid`, `albumid`), but
  # only `albumid` is used by ActiveRecord as the primary key. The `singerid` column is defined as a `parent_key` of
  # `albums` (see also the `db/migrate/01_create_tables.rb` file).
  has_many :tracks, foreign_key: "albumid"
end

class Track < ActiveRecord::Base
  # `tracks` is defined as INTERLEAVE IN PARENT `albums`. The primary key of `albums` is ()`singerid`, `albumid`).
  belongs_to :album, foreign_key: "albumid"

  # `tracks` also has a `singerid` column should be used to associate a Track with a Singer.
  belongs_to :singer, foreign_key: "singerid"

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

Run the application with the command

```bash
bundle exec rake run
```
