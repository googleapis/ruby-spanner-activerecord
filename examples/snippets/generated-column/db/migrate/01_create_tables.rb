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
        t.string :last_name, limit: 200, null: false

        # Create a generated column that contains the full name of the singer. This will be the concatenated first name
        # and last name of the singer, or only the last name if the first name is null. The `as` keyword is what
        # instructs the Spanner ActiveRecord adapter to create a generated column. Note the `stored` option that is set
        # to true. This is required, as Cloud Spanner (currently) does not support non-stored generated columns.
        # See also https://cloud.google.com/spanner/docs/generated-column/how-to for more information.
        t.string :full_name, limit: 300, null: false, as: "COALESCE(first_name || ' ', '') || last_name", stored: true
      end
    end
  end
end
