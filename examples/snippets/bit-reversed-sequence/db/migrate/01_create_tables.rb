# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[7.1]
  def change
    # Execute the entire migration as one DDL batch.
    connection.ddl_batch do
      connection.execute "create sequence singer_sequence OPTIONS (sequence_kind = 'bit_reversed_positive')"

      # Explicitly define the primary key.
      create_table :singers, id: false, primary_key: :singerid do |t|
        t.integer :singerid, primary_key: true, null: false,
                  default: -> { "GET_NEXT_SEQUENCE_VALUE(SEQUENCE singer_sequence)" }
        t.string :first_name
        t.string :last_name
      end

      create_table :albums, primary_key: [:singerid, :albumid], id: false do |t|
        # Interleave the `albums` table in the parent table `singers`.
        t.interleave_in :singers
        t.integer :singerid, null: false
        t.integer :albumid, null: false
        t.string :title
      end
    end
  end
end
