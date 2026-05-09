class CreateUtxos < ActiveRecord::Migration[7.2]
  def change
    create_table :utxos do |t|
      t.references :address, null: false, foreign_key: true
      t.string :txid, null: false
      t.integer :vout, null: false
      t.bigint :value_sats, null: false
      t.boolean :confirmed, null: false, default: false
      t.integer :block_height
      t.datetime :fetched_at

      t.timestamps
    end

    # Each UTXO is uniquely identified by (txid, vout) globally.
    add_index :utxos, [:txid, :vout], unique: true
    add_index :utxos, [:address_id, :confirmed]
  end
end
