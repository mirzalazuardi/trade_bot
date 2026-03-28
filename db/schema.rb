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

ActiveRecord::Schema[8.1].define(version: 2026_03_28_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "exchange_credentials", force: :cascade do |t|
    t.string "account_id", limit: 100
    t.string "api_key", limit: 500
    t.string "api_secret", limit: 1000
    t.datetime "created_at", null: false
    t.string "environment", default: "practice"
    t.string "exchange_name", null: false
    t.boolean "is_active", default: true
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "exchange_name"], name: "index_exchange_credentials_on_user_id_and_exchange_name", unique: true
    t.index ["user_id"], name: "index_exchange_credentials_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.boolean "remember_me", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "exchange_credentials", "users"
  add_foreign_key "sessions", "users"
end
