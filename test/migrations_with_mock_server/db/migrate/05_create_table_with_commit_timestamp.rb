# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTableWithCommitTimestamp < ActiveRecord::Migration[6.0]
  def change
    create_table :table1 do |t|
      t.string :value
      t.datetime :last_updated, allow_commit_timestamp: true
    end
  end
end
