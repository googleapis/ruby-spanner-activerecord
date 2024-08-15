# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true


def is_7_1_or_higher?
  ActiveRecord::gem_version >= Gem::Version.create('7.1.0')
end

def create_tables_in_test_schema
  ActiveRecord::Schema.define(version: 1) do
    ActiveRecord::Base.connection.ddl_batch do
      create_table :all_types, id: { limit: 8 } do |t|
        t.column :col_string, :string
        t.column :col_int64, :bigint
        t.column :col_float64, :float
        t.column :col_numeric, :numeric
        t.column :col_bool, :boolean
        t.column :col_bytes, :binary
        t.column :col_date, :date
        t.column :col_timestamp, :datetime
        t.column :col_json, :json

        t.column :col_array_string, :string, array: true
        t.column :col_array_int64, :bigint, array: true
        t.column :col_array_float64, :float, array: true
        t.column :col_array_numeric, :numeric, array: true
        t.column :col_array_bool, :boolean, array: true
        t.column :col_array_bytes, :binary, array: true
        t.column :col_array_date, :date, array: true
        t.column :col_array_timestamp, :datetime, array: true
        t.column :col_array_json, :json, array: true
      end

      create_table :firms do |t|
        t.string  :name
        t.integer :rating
        t.string :description
        t.references :account
      end

      create_table :customers do |t|
        t.string  :name
      end

      create_table :accounts do |t|
        t.references :customer, index: false
        t.references :firm, index: false
        t.string  :name
        t.integer :credit_limit
        t.integer :transactions_count
      end

      create_table :transactions do |t|
        t.float :amount
        t.references :account, index: false
      end

      create_table :departments do |t|
        t.string :name
        t.references :resource, polymorphic: true, index: { name: "index_departments_on_resource" }
      end

      create_table :member_types do |t|
        t.string :name
      end

      create_table :members do |t|
        t.string :name
        t.references :member_type, index: false
        t.references :admittable, polymorphic: true, index: false
      end

      create_table :memberships do |t|
        t.datetime :joined_on
        t.references :club, index: false
        t.references :member, index: false
        t.boolean :favourite
      end

      create_table :clubs do |t|
        t.string :name
      end

      create_table :authors do |t|
        t.string :name, null: false
        t.date :registered_date
        t.references :organization, index: false
      end

      create_table :posts do |t|
        t.string :title
        t.string :content
        t.references :author
        t.integer :comments_count
        t.date :post_date
        t.time :published_time
      end

      create_table :comments do |t|
        t.string :comment
        t.references :post, index: false, foreign_key: true
      end

      create_table :addresses do |t|
        t.string :line1
        t.string :postal_code
        t.string :city
        t.references :author, index: false
      end

      create_table :organizations do |t|
        t.string :name
        t.datetime :last_updated, allow_commit_timestamp: true
      end

      create_table :singers, id: false do |t|
        t.primary_key :singerid
        t.column :first_name, :string, limit: 200
        t.string :last_name
        t.integer :tracks_count
        t.integer :lock_version
        t.virtual :full_name, type: :string, as: "COALESCE(first_name || ' ', '') || last_name", stored: true
      end
      add_index :singers, :last_name, storing: %i[tracks_count first_name]

      if is_7_1_or_higher?
        create_table :albums, primary_key: [:singerid, :albumid] do |t|
          t.interleave_in :singers
          t.integer :singerid, null: false
          t.integer :albumid, null: false
          t.string :title
          t.integer :lock_version
        end
      else
        create_table :albums, id: false do |t|
          t.interleave_in :singers
          t.primary_key :albumid
          # `singerid` is part of the primary key in the table definition, but it is not visible to ActiveRecord as part of
          # the primary key, to prevent ActiveRecord from considering this to be an entity with a composite primary key.
          t.parent_key :singerid
          t.string :title
          t.integer :lock_version
        end
      end

      if is_7_1_or_higher?
        create_table :tracks, primary_key: [:singerid, :albumid, :trackid] do |t|
          # `:cascade` causes all tracks that belong to an album to automatically be deleted when an album is deleted.
          t.interleave_in :albums, :cascade
          t.integer :singerid, null: false
          t.integer :albumid, null: false
          t.integer :trackid, null: false
          t.string :title
          t.numeric :duration
          t.integer :lock_version
        end
      else
        create_table :tracks, id: false do |t|
          # `:cascade` causes all tracks that belong to an album to automatically be deleted when an album is deleted.
          t.interleave_in :albums, :cascade
          t.primary_key :trackid
          t.parent_key :singerid
          t.parent_key :albumid
          t.string :title
          t.numeric :duration
          t.integer :lock_version
        end
      end

      add_index :tracks, [:singerid, :albumid, :title], interleave_in: :albums, null_filtered: true, unique: false

      if ENV["SPANNER_EMULATOR_HOST"]
        create_table :table_with_sequence, id: false do |t|
          # The emulator does not yet support bit-reversed sequences, so we emulate a sequence value
          # by hashing a UUID instead.
          t.integer :id, primary_key: true, null: false, default: -> { "FARM_FINGERPRINT(GENERATE_UUID())" }
          t.string :name, null: false
          t.integer :age, null: false
        end
      else
        connection.execute "create sequence test_sequence OPTIONS (sequence_kind = 'bit_reversed_positive')"

        create_table :table_with_sequence, id: false do |t|
          t.integer :id, primary_key: true, null: false, default: -> { "GET_NEXT_SEQUENCE_VALUE(SEQUENCE test_sequence)" }
          t.string :name, null: false
          t.integer :age, null: false
        end
      end

    end
  end
end
