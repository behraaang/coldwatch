class CreateUsdSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :usd_snapshots do |t|
      t.date :captured_on, null: false
      t.decimal :price_usd, precision: 14, scale: 2, null: false
      t.string :source, null: false, default: "coingecko"

      t.timestamps
    end

    add_index :usd_snapshots, :captured_on, unique: true
  end
end
