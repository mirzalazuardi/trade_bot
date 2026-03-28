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

ActiveRecord::Schema[8.1].define(version: 2026_03_29_001102) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "approval_status", ["pending", "approved", "rejected", "expired"]
  create_enum "bot_mode", ["auto", "semi_auto"]
  create_enum "bot_status", ["active", "paused", "stopped"]
  create_enum "ml_model_status", ["testing", "active", "retired"]
  create_enum "order_status", ["pending", "submitted", "open", "partially_filled", "filled", "cancelled", "failed"]
  create_enum "position_status", ["open", "closed"]

  create_table "approvals", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.datetime "created_at", null: false
    t.decimal "estimated_fee", precision: 20, scale: 8
    t.datetime "expires_at"
    t.decimal "ml_confidence", precision: 5, scale: 2
    t.string "pair"
    t.decimal "price", precision: 20, scale: 8
    t.decimal "quantity", precision: 20, scale: 8
    t.string "side"
    t.enum "status", default: "pending", enum_type: "approval_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bot_id", "status"], name: "index_approvals_on_bot_id_and_status"
    t.index ["expires_at"], name: "index_approvals_on_expires_at"
    t.index ["user_id"], name: "index_approvals_on_user_id"
  end

  create_table "bots", force: :cascade do |t|
    t.boolean "ai_enabled", default: false
    t.datetime "created_at", null: false
    t.string "exchange_name"
    t.decimal "ml_high_threshold", precision: 5, scale: 2, default: "0.8"
    t.decimal "ml_low_threshold", precision: 5, scale: 2, default: "0.3"
    t.integer "ml_model_id"
    t.enum "mode", default: "auto", enum_type: "bot_mode"
    t.string "pair"
    t.enum "status", default: "active", enum_type: "bot_status"
    t.string "strategy"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["exchange_name", "status"], name: "index_bots_on_exchange_name_and_status"
    t.index ["user_id", "status"], name: "index_bots_on_user_id_and_status"
    t.index ["user_id"], name: "index_bots_on_user_id"
  end

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

  create_table "ml_models", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "feature_list", default: []
    t.string "file_path"
    t.string "model_type"
    t.string "name"
    t.jsonb "performance_metrics", default: {}
    t.enum "status", default: "testing", enum_type: "ml_model_status"
    t.date "training_date"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "version"
    t.index ["name", "version"], name: "index_ml_models_on_name_and_version", unique: true
    t.index ["status"], name: "index_ml_models_on_status"
    t.index ["training_date"], name: "index_ml_models_on_training_date"
    t.index ["user_id"], name: "index_ml_models_on_user_id"
  end

  create_table "ml_prediction_logs", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.decimal "confidence", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.jsonb "features_snapshot", default: {}
    t.bigint "ml_model_id", null: false
    t.string "signal_type"
    t.boolean "trade_executed", default: false
    t.boolean "trade_profitable", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bot_id", "created_at"], name: "index_ml_prediction_logs_on_bot_id_and_created_at"
    t.index ["bot_id"], name: "index_ml_prediction_logs_on_bot_id"
    t.index ["ml_model_id", "created_at"], name: "index_ml_prediction_logs_on_ml_model_id_and_created_at"
    t.index ["ml_model_id"], name: "index_ml_prediction_logs_on_ml_model_id"
    t.index ["user_id"], name: "index_ml_prediction_logs_on_user_id"
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

  create_table "orders", force: :cascade do |t|
    t.decimal "actual_fee_amount", precision: 20, scale: 8
    t.string "actual_fee_currency"
    t.bigint "bot_id", null: false
    t.datetime "created_at", null: false
    t.decimal "estimated_fee", precision: 20, scale: 8
    t.string "estimated_fee_currency"
    t.string "exchange_name"
    t.decimal "filled_price", precision: 20, scale: 8
    t.decimal "filled_quantity", precision: 20, scale: 8
    t.string "native_order_id"
    t.string "order_type"
    t.string "pair"
    t.decimal "price", precision: 20, scale: 8
    t.decimal "quantity", precision: 20, scale: 8
    t.string "side", default: "buy", null: false
    t.enum "status", default: "pending", enum_type: "order_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bot_id", "status"], name: "index_orders_on_bot_id_and_status"
    t.index ["exchange_name", "pair", "status"], name: "index_orders_on_exchange_name_and_pair_and_status"
    t.index ["native_order_id"], name: "index_orders_on_native_order_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "positions", force: :cascade do |t|
    t.decimal "average_price", precision: 20, scale: 8
    t.datetime "created_at", null: false
    t.string "exchange_name"
    t.decimal "gross_pnl", precision: 20, scale: 8, default: "0.0"
    t.decimal "net_pnl", precision: 20, scale: 8, default: "0.0"
    t.string "pair"
    t.decimal "price", precision: 20, scale: 8
    t.decimal "quantity", precision: 20, scale: 8
    t.string "side", default: "long", null: false
    t.enum "status", default: "open", enum_type: "position_status"
    t.decimal "total_fees", precision: 20, scale: 8, default: "0.0"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "exchange_name", "pair", "status"], name: "idx_on_user_id_exchange_name_pair_status_c9293b91c2", unique: true, where: "(status = 'open'::position_status)"
    t.index ["user_id"], name: "index_positions_on_user_id"
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

  create_table "trades", force: :cascade do |t|
    t.bigint "bot_id", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 20, scale: 8
    t.string "exchange_name"
    t.decimal "exit_price", precision: 20, scale: 8
    t.decimal "gross_pnl", precision: 20, scale: 8
    t.decimal "ml_confidence", precision: 5, scale: 2
    t.integer "ml_model_id"
    t.decimal "net_pnl", precision: 20, scale: 8
    t.bigint "order_id", null: false
    t.string "pair"
    t.decimal "quantity", precision: 20, scale: 8
    t.string "side"
    t.decimal "total_fees", precision: 20, scale: 8
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["bot_id", "closed_at"], name: "index_trades_on_bot_id_and_closed_at"
    t.index ["user_id", "closed_at"], name: "index_trades_on_user_id_and_closed_at"
    t.index ["user_id"], name: "index_trades_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.string "password_digest", null: false
    t.string "telegram_chat_id"
    t.boolean "telegram_enabled", default: false
    t.string "telegram_user_id"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "approvals", "bots"
  add_foreign_key "approvals", "users"
  add_foreign_key "bots", "users"
  add_foreign_key "exchange_credentials", "users"
  add_foreign_key "ml_models", "users"
  add_foreign_key "ml_prediction_logs", "bots"
  add_foreign_key "ml_prediction_logs", "ml_models"
  add_foreign_key "ml_prediction_logs", "users"
  add_foreign_key "monitored_pairs", "users"
  add_foreign_key "orders", "bots"
  add_foreign_key "orders", "users"
  add_foreign_key "positions", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "trades", "bots"
  add_foreign_key "trades", "orders"
  add_foreign_key "trades", "users"
end
