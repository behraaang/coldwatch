class AddNtfyTopicToWallets < ActiveRecord::Migration[7.2]
  def change
    # Encrypted at rest via Wallet's `encrypts :ntfy_topic`. Topic name is
    # the shared secret between the wallet's coldwatch instance and the
    # ntfy subscriber on the user's phone — leaking it lets anyone spam
    # the user with fake alarms or read incoming alerts (E2E will come later).
    add_column :wallets, :ntfy_topic, :text
  end
end
