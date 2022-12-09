# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 1) do
  connection.start_batch_ddl

  create_table "albums", id: { limit: 8 }, force: :cascade do |t|
    t.string "title"
    t.integer "singer_id", limit: 8
  end

  create_table "singers", id: { limit: 8 }, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
  end

  add_foreign_key "albums", "singers"
  connection.run_batch
rescue
  abort_batch
  raise
end
