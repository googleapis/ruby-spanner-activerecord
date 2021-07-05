# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTableWithGeneratedColumn < ActiveRecord::Migration[6.0]
  def change
    create_table :singers do |t|
      t.string :first_name, limit: 100
      t.string :last_name, limit: 200
      t.string :full_name, limit: 300, as: "COALESCE(first_name || ' ', '') || last_name", stored: true
    end
  end
end
