# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateInterleavedIndex < ActiveRecord::Migration[6.0]
  def change
    # Start a DDL batch that will be used for the entire change.
    connection.ddl_batch do
      add_index :albums, [:singerid, :title], interleave_in: :singers
    end
  end
end
