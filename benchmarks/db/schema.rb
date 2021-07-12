# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 1) do

  create_table "albums", force: :cascade do |t|
    t.string "title"
    t.date "release_date"
    t.integer "singer_id", limit: 8
  end

  create_table "singers", force: :cascade do |t|
    t.string "first_name", limit: 100
    t.string "last_name", limit: 200, null: false
    t.string "full_name", limit: 300, null: false
    t.date "birth_date"
    t.binary "picture"
  end

end
