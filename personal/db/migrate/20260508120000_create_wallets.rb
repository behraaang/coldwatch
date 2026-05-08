class CreateWallets < ActiveRecord::Migration[7.2]
  def change
    create_table :wallets do |t|
      t.string :name, null: false
      t.text :xpub, null: false
      t.string :network, null: false, default: "mainnet"
      t.integer :gap_limit, null: false, default: 20

      t.timestamps
    end

    add_index :wallets, :name, unique: true
  end
end
