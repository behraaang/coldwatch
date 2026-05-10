require "test_helper"

class WalletSyncJobTest < ActiveJob::TestCase
  setup do
    @wallet = Wallet.create!(name: "Sync Job W", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 2)
  end

  # Run the job's perform without exercising the Turbo Streams broadcast,
  # which is tested separately and would otherwise require ActionCable + a
  # full request context. We just need to know which collaborators were
  # invoked, in what order.
  def perform_with_broadcasts_stubbed
    Turbo::StreamsChannel.stub :broadcast_replace_to, nil do
      yield
    end
  end

  test "materializes addresses on first run, then syncs balances and UTXOs" do
    derivation_called = false
    sync_wallet_arg   = nil
    utxo_sync_calls   = []

    AddressDerivation.stub :materialize_all, ->(w) {
      derivation_called = true
      w.addresses.create!(address: "bc1qused1", branch: 0, index_at_branch: 0, tx_count: 1)
      w.addresses.create!(address: "bc1qunused", branch: 0, index_at_branch: 1, tx_count: 0)
    } do
      MempoolFetcher.stub :sync_wallet, ->(w) { sync_wallet_arg = w; { synced: 2, failed: [] } } do
        UtxoSyncer.stub :sync_address, ->(addr) { utxo_sync_calls << addr.address } do
          perform_with_broadcasts_stubbed do
            WalletSyncJob.new.perform(@wallet)
          end
        end
      end
    end

    assert derivation_called, "AddressDerivation.materialize_all should be invoked"
    assert_equal @wallet, sync_wallet_arg
    assert_equal ["bc1qused1"], utxo_sync_calls,
                 "only addresses with activity should be UTXO-synced"
  end

  test "skips materialization when addresses already exist" do
    @wallet.addresses.create!(address: "bc1qpre", branch: 0, index_at_branch: 0, tx_count: 0)

    derivation_called = false
    AddressDerivation.stub :materialize_all, ->(_) { derivation_called = true } do
      MempoolFetcher.stub :sync_wallet, ->(_) { { synced: 1, failed: [] } } do
        UtxoSyncer.stub :sync_address, ->(_) {} do
          perform_with_broadcasts_stubbed do
            WalletSyncJob.new.perform(@wallet)
          end
        end
      end
    end

    refute derivation_called, "must not re-derive when addresses already exist"
  end
end
