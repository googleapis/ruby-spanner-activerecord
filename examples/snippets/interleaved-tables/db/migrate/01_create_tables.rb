# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[7.1]
  def change
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
  end
end
