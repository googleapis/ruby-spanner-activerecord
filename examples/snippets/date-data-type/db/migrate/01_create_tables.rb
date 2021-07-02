# Copyright 2021 Google LLC
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
        # A date in Cloud Spanner represents a timezone independent date. It does not designate a specific point in
        # time, such as for example midnight UTC of the specified date.
        # See https://cloud.google.com/spanner/docs/data-definition-language#data_types for more information.
        t.date   :birth_date
      end
    end
  end
end
