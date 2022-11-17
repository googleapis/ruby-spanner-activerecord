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

  create_table "entity_with_array_types", id: { limit: 8 }, force: :cascade do |t|
    t.string "col_array_string"
    t.integer "col_array_int64", limit: 8
    t.float "col_array_float64"
    t.decimal "col_array_numeric"
    t.boolean "col_array_bool"
    t.binary "col_array_bytes"
    t.date "col_array_date"
    t.time "col_array_timestamp"
  end

  connection.run_batch
rescue
  abort_batch
  raise
end
