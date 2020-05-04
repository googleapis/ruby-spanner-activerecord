# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# frozen_string_literal: true

ActiveRecord::Schema.define do
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
  end
end