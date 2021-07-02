# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateTables < ActiveRecord::Migration[6.0]
  def change
    connection.ddl_batch do
      create_table :meetings do |t|
        t.string :title
        # A `TIMESTAMP` column in Cloud Spanner contains a date/time value that designates a specific point in time. The
        # value is always stored in UTC. If you specify a date/time value in a different timezone, the value is
        # converted to UTC when saving it to the database. You can use a separate column to store the timezone of the
        # timestamp if that is vital for your application, and use that information when the timestamp is read back.
        t.datetime :meeting_time
        t.string   :meeting_timezone
      end
    end
  end
end
