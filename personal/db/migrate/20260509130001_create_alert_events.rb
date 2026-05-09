class CreateAlertEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :alert_events do |t|
      t.references :wallet, null: false, foreign_key: true
      t.string :txid, null: false
      t.string :direction, null: false               # "outgoing" — Day 5 only persists outgoing alarms
      t.bigint :amount_sats
      t.boolean :confirmed, null: false, default: false
      t.integer :block_height
      t.datetime :dispatched_at                      # when the ntfy push went out

      t.timestamps
    end

    # Idempotency — same tx detected twice shouldn't double-alarm
    add_index :alert_events, [:wallet_id, :txid], unique: true
    add_index :alert_events, :dispatched_at
  end
end
