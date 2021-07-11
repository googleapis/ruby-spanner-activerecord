# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateIndexStoring < ActiveRecord::Migration[6.0]
  def change
    connection.ddl_batch do
      add_index :singers, :full_name, storing: [:first_name, :last_name]
    end
  end
end
