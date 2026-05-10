require "test_helper"

class UtxoSyncerTest < ActiveSupport::TestCase
  setup do
    @wallet  = Wallet.create!(name: "Utxo Sync W", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5)
    @address = @wallet.addresses.create!(address: "bc1qsync", branch: 0, index_at_branch: 0)
  end

  def utxo_response(*tuples)
    tuples.map do |txid, vout, value, confirmed = true, height = 880_000|
      {
        "txid"   => txid,
        "vout"   => vout,
        "value"  => value,
        "status" => { "confirmed" => confirmed, "block_height" => height }
      }
    end
  end

  test "creates new utxos returned by mempool" do
    fresh = utxo_response(["a" * 64, 0, 100_000], ["b" * 64, 1, 50_000])
    MempoolFetcher.stub :fetch_utxos, fresh do
      UtxoSyncer.sync_address(@address)
    end
    assert_equal 2, @address.utxos.count
    a = @address.utxos.find_by(txid: "a" * 64, vout: 0)
    assert_equal 100_000, a.value_sats
    assert a.confirmed
  end

  test "updates existing utxos in place" do
    existing = @address.utxos.create!(
      txid: "a" * 64, vout: 0, value_sats: 100_000, confirmed: false
    )
    fresh = utxo_response(["a" * 64, 0, 100_000, true, 881_000])
    MempoolFetcher.stub :fetch_utxos, fresh do
      UtxoSyncer.sync_address(@address)
    end
    existing.reload
    assert existing.confirmed
    assert_equal 881_000, existing.block_height
  end

  test "deletes orphan utxos that no longer appear in the response (spent)" do
    keep   = @address.utxos.create!(txid: "k" * 64, vout: 0, value_sats: 80_000)
    spent  = @address.utxos.create!(txid: "s" * 64, vout: 0, value_sats: 30_000)

    fresh = utxo_response(["k" * 64, 0, 80_000])
    MempoolFetcher.stub :fetch_utxos, fresh do
      UtxoSyncer.sync_address(@address)
    end

    assert Utxo.exists?(keep.id)
    refute Utxo.exists?(spent.id)
  end

  test "is a no-op when fetch_utxos returns nil (network failure)" do
    @address.utxos.create!(txid: "p" * 64, vout: 0, value_sats: 5_000)
    MempoolFetcher.stub :fetch_utxos, nil do
      UtxoSyncer.sync_address(@address)
    end
    assert_equal 1, @address.utxos.count, "must not delete on transient failure"
  end

  test "skips entries with blank txid in the response" do
    fresh = [{ "txid" => "", "vout" => 0, "value" => 1_000, "status" => {} }]
    MempoolFetcher.stub :fetch_utxos, fresh do
      UtxoSyncer.sync_address(@address)
    end
    assert_equal 0, @address.utxos.count
  end
end
