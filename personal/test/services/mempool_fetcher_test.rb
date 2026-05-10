require "test_helper"

class MempoolFetcherTest < ActiveSupport::TestCase
  BASE = MempoolFetcher::BASE_URLS.fetch("mainnet")

  test "fetch parses balance from chain_stats + mempool_stats" do
    body = {
      "chain_stats"   => { "funded_txo_sum" => 1_000_000, "spent_txo_sum" => 100_000, "tx_count" => 5 },
      "mempool_stats" => { "funded_txo_sum" => 50_000,    "spent_txo_sum" => 0,       "tx_count" => 1 }
    }.to_json

    HttpStub.with_response(body: body) do
      result = MempoolFetcher.fetch("bc1qfoo", base: BASE)
      assert_equal 950_000, result[:balance_sats]
      assert_equal 6, result[:tx_count]
    end
  end

  test "fetch tolerates missing mempool_stats fields" do
    body = {
      "chain_stats" => { "funded_txo_sum" => 200_000, "spent_txo_sum" => 50_000, "tx_count" => 2 }
    }.to_json

    HttpStub.with_response(body: body) do
      result = MempoolFetcher.fetch("bc1qfoo", base: BASE)
      assert_equal 150_000, result[:balance_sats]
      assert_equal 2, result[:tx_count]
    end
  end

  test "fetch returns nil on a non-success response" do
    HttpStub.with_response(body: "boom", status: 500) do
      assert_nil MempoolFetcher.fetch("bc1qfoo", base: BASE)
    end
  end

  test "fetch returns nil and logs on a network exception" do
    HttpStub.with_raise(Errno::ECONNREFUSED, message: "refused") do
      assert_nil MempoolFetcher.fetch("bc1qfoo", base: BASE)
    end
  end

  test "sync_wallet raises ArgumentError for an unknown network" do
    wallet = Wallet.new(name: "X", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 1)
    wallet.network = "regtest"  # bypass validation
    assert_raises(ArgumentError) { MempoolFetcher.sync_wallet(wallet) }
  end

  test "sync_wallet updates each address with parsed balance + tx_count" do
    wallet = Wallet.create!(name: "Sync W", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 1)
    a1 = wallet.addresses.create!(address: "bc1qa", branch: 0, index_at_branch: 0)
    a2 = wallet.addresses.create!(address: "bc1qb", branch: 0, index_at_branch: 1)

    body = {
      "chain_stats"   => { "funded_txo_sum" => 100_000, "spent_txo_sum" => 0, "tx_count" => 1 },
      "mempool_stats" => { "funded_txo_sum" => 0,       "spent_txo_sum" => 0, "tx_count" => 0 }
    }.to_json

    HttpStub.with_response(body: body) do
      result = MempoolFetcher.sync_wallet(wallet)
      assert_equal 2, result[:synced]
      assert_empty result[:failed]
    end

    assert_equal 100_000, a1.reload.balance_sats
    assert_equal 1,       a1.tx_count
    assert_not_nil a1.last_synced_at
    assert_equal 100_000, a2.reload.balance_sats
  end

  test "fetch_txs returns the parsed array on success and nil on error" do
    HttpStub.with_response(body: '[{"txid":"abc"}]') do
      assert_equal [{ "txid" => "abc" }], MempoolFetcher.fetch_txs("bc1qfoo", base: BASE)
    end
    HttpStub.with_response(body: "boom", status: 500) do
      assert_nil MempoolFetcher.fetch_txs("bc1qfoo", base: BASE)
    end
  end

  test "fetch_utxos returns the parsed array on success and nil on error" do
    body = [{ "txid" => "a", "vout" => 0, "value" => 1234, "status" => { "confirmed" => true } }].to_json
    HttpStub.with_response(body: body) do
      result = MempoolFetcher.fetch_utxos("bc1qfoo", base: BASE)
      assert_equal 1, result.length
      assert_equal "a", result.first["txid"]
    end
  end
end
