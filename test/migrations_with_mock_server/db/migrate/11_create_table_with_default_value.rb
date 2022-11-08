# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTableWithDefaultValue < ActiveRecord::Migration[6.0]
  def change
    create_table :singers do |t|
      t.string :name, null: false, default: "no name"
      t.integer :age, null: false, default: 0
    end
  end
end
