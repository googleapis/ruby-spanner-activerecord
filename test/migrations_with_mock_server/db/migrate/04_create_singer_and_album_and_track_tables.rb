# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateSingerAndAlbumAndTrackTables < ActiveRecord::Migration[6.0]
  def change
    # Record the current primary key prefix type to reset it after running this change.
    current_prefix_type = ActiveRecord::Base.primary_key_prefix_type
    begin
      # Interleaved tables require that the child table includes the column(s) of the primary key of the parent table.
      # That means that the tables should use a prefix for the primary key column names in order to prevent the primary
      # key columns of both the parent and child tables to be named `id`.
      ActiveRecord::Base.primary_key_prefix_type = :table_name
      # Start a DDL batch that will be used for the entire change.
      connection.start_batch_ddl
      create_table :singers do |t|
        t.column :first_name, :string, limit: 200
        t.string :last_name
      end

      # To create an interleaved table we need to do the following:
      # 1. Disable the automatic generation of a primary key. Otherwise, ActiveRecord will generate a single column
      #    primary key named `id` or `albumid` (depending on the primary_key_prefix_type).
      # 2. Call `t.interleave_in :table` to register the parent table.
      # 3. Manually add the primary key columns in the correct order. In this case that is `singerid` (the primary key
      #    of the parent table) and `albumid`.
      create_table :albums do |t|
        t.interleave_in :singers
        t.parent_key :singerid
        t.string :title
      end

      # Add a unique index to the albumid column to prevent full table scans when a single album record is queried.
      add_index :albums, [:albumid], unique: true

      # This table will be interleaved in a table that itself is already an interleaved table. We need to include the
      # primary key columns of all the parent tables in the hierarchy.
      create_table :tracks do |t|
        t.interleave_in :albums, :cascade
        t.parent_key :singerid
        t.parent_key :albumid
        t.string :title
        t.numeric :duration
      end

      # Add a unique index to the trackid column to prevent full table scans when a single track record is queried.
      add_index :tracks, [:trackid], unique: true

      # Execute the change as one DDL batch.
      connection.run_batch
    rescue StandardError
      connection.abort_batch
      raise
    ensure
      ActiveRecord::Base.primary_key_prefix_type = current_prefix_type
    end
  end
end
