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
    t.integer "singers_id", limit: 8
    t.index ["singers_id"], name: "index_albums_on_singers_id", order: { singers_id: :asc }
  end

  create_table "singers", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
  end

  create_table "tracks", force: :cascade do |t|
    t.string "title"
    t.decimal "duration"
    t.integer "albums_id", limit: 8
    t.index ["albums_id"], name: "index_tracks_on_albums_id", order: { albums_id: :asc }
  end

end
