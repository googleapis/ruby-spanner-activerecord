# Copyright 2025 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[7.1]
  def change
    # Execute the entire migration as one DDL batch.
    connection.ddl_batch do
      create_table :singers, id: false, primary_key: :singerid do |t|
        # Use the ':primary_key' data type to create an auto-generated primary key column.
        t.column :singerid, :primary_key, primary_key: true, null: false
        t.string :first_name
        t.string :last_name
      end

      create_table :albums, primary_key: [:singerid, :albumid], id: false do |t|
        # Interleave the `albums` table in the parent table `singers`.
        t.interleave_in :singers
        t.integer :singerid, null: false
        # Use the ':primary_key' data type to create an auto-generated primary key column.
        t.column :albumid, :primary_key, null: false
        t.string :title
      end
    end
  end
end
