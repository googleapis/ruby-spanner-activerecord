# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[6.0]
  def change
    connection.ddl_batch do
      create_table :singers do |t|
        t.string :first_name
        t.string :last_name
      end

      create_table :albums do |t|
        t.string :title
        t.references :singer, index: false, foreign_key: true
      end
    end
  end
end
