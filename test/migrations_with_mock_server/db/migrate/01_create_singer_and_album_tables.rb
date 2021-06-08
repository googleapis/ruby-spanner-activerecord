# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateSingerAndAlbumTables < ActiveRecord::Migration[6.0]
  def change
    current_prefix_type = ActiveRecord::Base.primary_key_prefix_type
    begin
      ActiveRecord::Base.primary_key_prefix_type = :table_name
      create_table :singers do |t|
        t.column :first_name, :string, limit: 200
        t.string :last_name
      end

      create_table :albums do |t|
        t.string :title
        t.integer :singer_id
      end

      add_foreign_key :albums, :singers

      add_column :singers, "place_of_birth", "STRING(MAX)"

      create_join_table :singers, :albums
    ensure
      ActiveRecord::Base.primary_key_prefix_type = current_prefix_type
    end
  end
end
