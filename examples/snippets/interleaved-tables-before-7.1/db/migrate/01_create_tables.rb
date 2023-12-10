# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[6.0]
  def change
    # Execute the entire migration as one DDL batch.
    connection.ddl_batch do
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
    end
  end
end
