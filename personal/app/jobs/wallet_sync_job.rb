# Idempotent end-to-end sync for a wallet:
#   1. Materialize all derived addresses (BIP84 receive + change up to gap_limit)
#   2. Fetch balance/tx_count for every address from mempool.space REST
#   3. Broadcast Turbo Stream updates to the show page after each phase
#
# Enqueued from WalletsController#create and #sync.
# Runs in the sidekiq container; broadcasts reach the web container via
# the Redis-backed ActionCable adapter.
class WalletSyncJob < ApplicationJob
  queue_as :default

  def perform(wallet)
    # Phase 1: materialize addresses if missing. Slow on first run (~3s for
    # 10 addresses; ~12s for the default 40), idempotent after.
    unless wallet.addresses.exists?
      AddressDerivation.materialize_all(wallet)
      broadcast_addresses(wallet)
    end

    # Phase 2: fetch balances. ~200ms per address against mempool.space.
    MempoolFetcher.sync_wallet(wallet)
    broadcast_balance(wallet)
    broadcast_addresses(wallet)
  end

  private

  def broadcast_balance(wallet)
    Turbo::StreamsChannel.broadcast_replace_to(
      wallet,
      target: ActionView::RecordIdentifier.dom_id(wallet, :balance_card),
      partial: "wallets/balance_card",
      locals: { wallet: wallet }
    )
  end

  def broadcast_addresses(wallet)
    Turbo::StreamsChannel.broadcast_replace_to(
      wallet,
      target: ActionView::RecordIdentifier.dom_id(wallet, :addresses_panel),
      partial: "wallets/addresses_panel",
      locals: {
        wallet: wallet,
        receive_addresses: wallet.addresses.receive.ordered,
        change_addresses:  wallet.addresses.change.ordered
      }
    )
  end
end
