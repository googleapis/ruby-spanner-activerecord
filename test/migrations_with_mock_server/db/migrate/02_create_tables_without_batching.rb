# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTablesWithoutBatching < ActiveRecord::Migration[6.0]
  def change
    # Create two tables without using DDL batching.
    create_table :table1 do |t|
      t.string :col1
      t.string :col2
    end

    create_table :table2 do |t|
      t.string :col1
      t.string :col2
    end
  end
end
