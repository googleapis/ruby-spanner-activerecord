# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

ActiveRecord::Schema.define do
  ActiveRecord::Base.connection.ddl_batch do
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
      t.references :resource, polymorphic: true
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
    end

    create_table :albums, id: false do |t|
      t.interleave_in :singers
      t.primary_key :albumid
      # `singerid` is part of the primary key in the table definition, but it is not visible to ActiveRecord as part of
      # the primary key, to prevent ActiveRecord from considering this to be an entity with a composite primary key.
      t.parent_key :singerid
      t.string :title
    end

    create_table :tracks, id: false do |t|
      # `:cascade` causes all tracks that belong to an album to automatically be deleted when an album is deleted.
      t.interleave_in :albums, :cascade
      t.primary_key :trackid
      t.parent_key :singerid
      t.parent_key :albumid
      t.string :title
      t.numeric :duration
    end
  end
end