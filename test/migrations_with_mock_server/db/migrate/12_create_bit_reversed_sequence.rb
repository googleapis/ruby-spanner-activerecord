# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class CreateBitReversedSequence < ActiveRecord::Migration[6.0]
  def change
    connection.start_batch_ddl
    connection.execute "create sequence test_sequence OPTIONS (sequence_kind = 'bit_reversed_positive')"

    create_table :table_with_sequence, id: false do |t|
      t.integer :id, primary_key: true, null: false, default: -> { "GET_NEXT_SEQUENCE_VALUE(SEQUENCE test_sequence)" }
      t.string :name, null: false
      t.integer :age, null: false
    end
    connection.run_batch
  end
end
