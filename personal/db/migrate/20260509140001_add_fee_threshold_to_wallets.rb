class AddFeeThresholdToWallets < ActiveRecord::Migration[7.2]
  def change
    # Threshold in sats per virtual byte. When mempool.space's recommended
    # fee drops below this, the user gets an ntfy alert via FeeMonitorJob.
    # Nil = fee monitor disabled for this wallet.
    add_column :wallets, :fee_threshold_sat_vb, :integer

    # last_fee_alert_at: dedupe so we don't spam if fees stay low for hours.
    add_column :wallets, :last_fee_alert_at, :datetime
  end
end
