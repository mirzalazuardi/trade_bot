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

ActiveRecord::Schema[8.1].define(version: 2026_03_29_001000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "candles", force: :cascade do |t|
    t.decimal "close", precision: 20, scale: 8, null: false
    t.boolean "closed", default: true
    t.datetime "created_at", null: false
    t.string "exchange_name", null: false
    t.decimal "high", precision: 20, scale: 8, null: false
    t.string "interval", null: false
    t.decimal "low", precision: 20, scale: 8, null: false
    t.decimal "open", precision: 20, scale: 8, null: false
    t.string "pair", null: false
    t.bigint "timestamp", null: false
    t.datetime "updated_at", null: false
    t.decimal "volume", precision: 30, scale: 8
    t.index ["exchange_name", "pair", "interval", "created_at"], name: "idx_candle_cleanup"
    t.index ["exchange_name", "pair", "interval", "timestamp"], name: "idx_candle_unique", unique: true
  end

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

  create_table "exchange_fees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exchange_name", null: false
    t.boolean "is_active", default: true
    t.decimal "maker_rate", precision: 6, scale: 4, default: "0.0"
    t.boolean "spread_based", default: false
    t.decimal "taker_rate", precision: 6, scale: 4, default: "0.0"
    t.jsonb "typical_spreads", default: {}
    t.datetime "updated_at", null: false
    t.index ["exchange_name"], name: "index_exchange_fees_on_exchange_name", unique: true
  end

  create_table "monitored_pairs", force: :cascade do |t|
    t.boolean "collect_candles", default: true
    t.integer "collect_interval", default: 60
    t.boolean "collect_ticker", default: true
    t.datetime "created_at", null: false
    t.string "exchange_name", null: false
    t.string "interval", default: "1h"
    t.boolean "is_active", default: true
    t.string "pair", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "exchange_name", "pair"], name: "idx_monitored_pair_unique", unique: true
    t.index ["user_id"], name: "index_monitored_pairs_on_user_id"
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

  create_table "tickers", force: :cascade do |t|
    t.decimal "ask", precision: 20, scale: 8
    t.decimal "bid", precision: 20, scale: 8
    t.datetime "created_at", null: false
    t.string "exchange_name", null: false
    t.decimal "high_24h", precision: 20, scale: 8
    t.decimal "last", precision: 20, scale: 8
    t.decimal "low_24h", precision: 20, scale: 8
    t.string "pair", null: false
    t.decimal "price_change_24h", precision: 20, scale: 8
    t.decimal "price_change_percent_24h", precision: 10, scale: 4
    t.bigint "timestamp", null: false
    t.datetime "updated_at", null: false
    t.decimal "volume_24h", precision: 30, scale: 8
    t.index ["exchange_name", "pair"], name: "idx_ticker_unique", unique: true
    t.index ["updated_at"], name: "idx_ticker_stale"
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
  add_foreign_key "monitored_pairs", "users"
  add_foreign_key "sessions", "users"
end
