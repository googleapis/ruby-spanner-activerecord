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

  create_table "albums", primary_key: "albumid", force: :cascade do |t|
    t.integer "singerid", limit: 8, null: false
    t.string "title"
  end

  create_table "singers", primary_key: "singerid", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
  end

  create_table "tracks", primary_key: "trackid", force: :cascade do |t|
    t.integer "singerid", limit: 8, null: false
    t.integer "albumid", limit: 8, null: false
    t.string "title"
    t.decimal "duration"
  end

  connection.run_batch
rescue
  abort_batch
  raise
end
