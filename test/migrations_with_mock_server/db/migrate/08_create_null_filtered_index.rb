# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateNullFilteredIndex < ActiveRecord::Migration[6.0]
  def change
    connection.ddl_batch do
      add_index :singers, :picture, null_filtered: true
    end
  end
end
