# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :firms, force: true do |t|
    t.string  :name
    t.integer :rating
    t.string :description
    t.references :account
  end

  create_table :customers, force: true do |t|
    t.string  :name
  end

  create_table :accounts, force: true do |t|
    t.references :customer, index: false
    t.references :firm, index: false
    t.string  :name
    t.integer :credit_limit
    t.integer :transactions_count
  end

  create_table :transactions, force: true do |t|
    t.float :amount
    t.references :account, index: false
  end

  create_table :departments, force: true do |t|
    t.string :name
    t.references :resource, polymorphic: true
  end

  create_table :member_types, force: true do |t|
    t.string :name
  end

  create_table :members, force: true do |t|
    t.string :name
    t.references :member_type, index: false
    t.references :admittable, polymorphic: true, index: false
  end

  create_table :memberships, force: true do |t|
    t.datetime :joined_on
    t.references :club, index: false
    t.references :member, index: false
    t.boolean :favourite
  end

  create_table :clubs, force: true do |t|
    t.string :name
  end
end