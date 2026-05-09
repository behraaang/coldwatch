class CreateAddresses < ActiveRecord::Migration[7.2]
  def change
    create_table :addresses do |t|
      t.references :wallet, null: false, foreign_key: true
      t.string :address, null: false
      t.integer :branch, null: false           # 0 = receive, 1 = change
      t.integer :index_at_branch, null: false
      t.bigint :balance_sats, null: false, default: 0
      t.bigint :tx_count, null: false, default: 0
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :addresses, :address, unique: true
    add_index :addresses, [:wallet_id, :branch, :index_at_branch],
              unique: true, name: "idx_addresses_wallet_branch_index"
  end
end
