# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateAllNativeMigrationTypes < ActiveRecord::Migration[6.0]
  def change
    # Create a table with all native migration types.
    # https://api.rubyonrails.org/v6.1.3.2/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_column
    create_table :types_table do |t|
      t.column :col_string, :string
      t.column :col_text, :text
      t.column :col_integer, :integer
      t.column :col_bigint, :bigint
      t.column :col_float, :float
      t.column :col_decimal, :decimal
      t.column :col_numeric, :numeric
      t.column :col_datetime, :datetime
      t.column :col_time, :time
      t.column :col_date, :date
      t.column :col_binary, :binary
      t.column :col_boolean, :boolean
      t.column :col_json, :json
      t.column :col_uuid, :uuid

      t.column :col_array_string, :string, array: true
      t.column :col_array_text, :text, array: true
      t.column :col_array_integer, :integer, array: true
      t.column :col_array_bigint, :bigint, array: true
      t.column :col_array_float, :float, array: true
      t.column :col_array_decimal, :decimal, array: true
      t.column :col_array_numeric, :numeric, array: true
      t.column :col_array_datetime, :datetime, array: true
      t.column :col_array_time, :time, array: true
      t.column :col_array_date, :date, array: true
      t.column :col_array_binary, :binary, array: true
      t.column :col_array_boolean, :boolean, array: true
      t.column :col_array_json, :json, array: true
      t.column :col_array_uuid, :uuid, array: true
    end
  end
end

