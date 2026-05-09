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

ActiveRecord::Schema[7.2].define(version: 2026_05_09_100000) do
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

  create_table "wallets", force: :cascade do |t|
    t.string "name", null: false
    t.text "xpub", null: false
    t.string "network", default: "mainnet", null: false
    t.integer "gap_limit", default: 20, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_wallets_on_name", unique: true
  end

  add_foreign_key "addresses", "wallets"
end
