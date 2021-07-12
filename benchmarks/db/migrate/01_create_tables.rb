# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[6.0]
  def change
    connection.ddl_batch do
      create_table :singers do |t|
        t.string :first_name, limit: 100
        t.string :last_name, null: false, limit: 200
        t.string :full_name, null: false, limit: 300, as: "COALESCE(first_name || ' ', '') || last_name", stored: true
        t.date :birth_date
        t.binary :picture
      end

      create_table :albums do |t|
        t.string :title
        t.date :release_date
        t.references :singer, index: false
      end
    end
  end
end
