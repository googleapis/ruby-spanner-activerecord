# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[6.0]
  def change
    # Execute the entire migration as one DDL batch.
    connection.ddl_batch do
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
    end
  end
end
