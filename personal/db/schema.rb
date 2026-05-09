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

ActiveRecord::Schema[7.2].define(version: 2026_05_09_140002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "wallet_id", null: false
    t.string "address", null: false
    t.integer "branch", null: false
    t.integer "index_at_branch", null: false
    t.bigint "balance_sats", default: 0, null: false
    t.bigint "tx_count", default: 0, null: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_addresses_on_address", unique: true
    t.index ["wallet_id", "branch", "index_at_branch"], name: "idx_addresses_wallet_branch_index", unique: true
    t.index ["wallet_id"], name: "index_addresses_on_wallet_id"
  end

  create_table "alert_events", force: :cascade do |t|
    t.bigint "wallet_id", null: false
    t.string "txid", null: false
    t.string "direction", null: false
    t.bigint "amount_sats"
    t.boolean "confirmed", default: false, null: false
    t.integer "block_height"
    t.datetime "dispatched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dispatched_at"], name: "index_alert_events_on_dispatched_at"
    t.index ["wallet_id", "txid"], name: "index_alert_events_on_wallet_id_and_txid", unique: true
    t.index ["wallet_id"], name: "index_alert_events_on_wallet_id"
  end

  create_table "usd_snapshots", force: :cascade do |t|
    t.date "captured_on", null: false
    t.decimal "price_usd", precision: 14, scale: 2, null: false
    t.string "source", default: "coingecko", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["captured_on"], name: "index_usd_snapshots_on_captured_on", unique: true
  end

  create_table "utxos", force: :cascade do |t|
    t.bigint "address_id", null: false
    t.string "txid", null: false
    t.integer "vout", null: false
    t.bigint "value_sats", null: false
    t.boolean "confirmed", default: false, null: false
    t.integer "block_height"
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address_id", "confirmed"], name: "index_utxos_on_address_id_and_confirmed"
    t.index ["address_id"], name: "index_utxos_on_address_id"
    t.index ["txid", "vout"], name: "index_utxos_on_txid_and_vout", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.string "name", null: false
    t.text "xpub", null: false
    t.string "network", default: "mainnet", null: false
    t.integer "gap_limit", default: 20, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "ntfy_topic"
    t.integer "fee_threshold_sat_vb"
    t.datetime "last_fee_alert_at"
    t.index ["name"], name: "index_wallets_on_name", unique: true
  end

  add_foreign_key "addresses", "wallets"
  add_foreign_key "alert_events", "wallets"
  add_foreign_key "utxos", "addresses"
end
