# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

class CreateParentAndChildWithUuidPk < ActiveRecord::Migration[6.0]
  def change
    # Execute the entire migration as one DDL batch.
    connection.ddl_batch do
      create_table :parent_with_uuid_pk, id: false do |t|
        t.primary_key :parentid, :string, limit: 36
        t.string :first_name
        t.string :last_name
      end

      create_table :child_with_uuid_pk, id: false do |t|
        t.interleave_in :parent_with_uuid_pk
        t.parent_key :parentid, type: 'STRING(36)'
        t.primary_key :childid
        t.string :title
      end
    end
  end
end

