require "test_helper"

class WalletTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    {
      name:      "Cold Storage",
      xpub:      FAKE_ZPUB,
      network:   "mainnet",
      gap_limit: 20
    }.merge(overrides)
  end

  test "is valid with mainnet zpub + required attrs" do
    assert Wallet.new(valid_attrs).valid?
  end

  test "requires a name" do
    w = Wallet.new(valid_attrs(name: nil))
    refute w.valid?
    assert_includes w.errors[:name], "can't be blank"
  end

  test "name uniqueness is case-insensitive" do
    Wallet.create!(valid_attrs)
    dup = Wallet.new(valid_attrs(name: "COLD STORAGE", xpub: FAKE_ZPUB))
    refute dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "requires an xpub" do
    w = Wallet.new(valid_attrs(xpub: nil))
    refute w.valid?
    assert_includes w.errors[:xpub], "can't be blank"
  end

  test "rejects an unknown network" do
    w = Wallet.new(valid_attrs(network: "regtest"))
    refute w.valid?
    assert_includes w.errors[:network], "is not included in the list"
  end

  test "rejects gap_limit at or below 0 and above 100" do
    refute Wallet.new(valid_attrs(gap_limit: 0)).valid?
    refute Wallet.new(valid_attrs(gap_limit: 101)).valid?
    assert  Wallet.new(valid_attrs(gap_limit: 1)).valid?
    assert  Wallet.new(valid_attrs(gap_limit: 100)).valid?
  end

  test "rejects mainnet wallet with a vpub xpub" do
    w = Wallet.new(valid_attrs(xpub: FAKE_VPUB))
    refute w.valid?
    assert(w.errors[:xpub].any? { |m| m.include?("zpub") })
  end

  test "rejects testnet wallet with a zpub xpub" do
    w = Wallet.new(valid_attrs(network: "testnet", xpub: FAKE_ZPUB))
    refute w.valid?
    assert(w.errors[:xpub].any? { |m| m.include?("vpub") })
  end

  test "accepts testnet wallet with vpub" do
    assert Wallet.new(valid_attrs(network: "testnet", xpub: FAKE_VPUB)).valid?
  end

  test "ntfy_topic format is enforced when present" do
    refute Wallet.new(valid_attrs(ntfy_topic: "too short")).valid?  # has space
    refute Wallet.new(valid_attrs(ntfy_topic: "abc")).valid?         # < 8 chars
    assert Wallet.new(valid_attrs(ntfy_topic: "ok_topic-12345")).valid?
  end

  test "ntfy_topic is allowed to be blank" do
    assert Wallet.new(valid_attrs(ntfy_topic: nil)).valid?
    assert Wallet.new(valid_attrs(ntfy_topic: "")).valid?
  end

  test "fee_threshold_sat_vb must be 1..1000 when present" do
    refute Wallet.new(valid_attrs(fee_threshold_sat_vb: 0)).valid?
    refute Wallet.new(valid_attrs(fee_threshold_sat_vb: 1001)).valid?
    assert Wallet.new(valid_attrs(fee_threshold_sat_vb: 5)).valid?
    assert Wallet.new(valid_attrs(fee_threshold_sat_vb: nil)).valid?
  end

  test "xpub is encrypted at rest (raw column does not contain the plaintext)" do
    wallet = Wallet.create!(valid_attrs)
    raw = ActiveRecord::Base.connection.execute(
      "SELECT xpub FROM wallets WHERE id = #{wallet.id}"
    ).first.fetch("xpub")
    refute_equal FAKE_ZPUB, raw
    assert_equal FAKE_ZPUB, wallet.reload.xpub
  end

  test "balance_sats sums address balances and balance_btc divides by 1e8" do
    wallet = Wallet.create!(valid_attrs)
    wallet.addresses.create!(address: "bc1qa", branch: 0, index_at_branch: 0, balance_sats: 60_000_000)
    wallet.addresses.create!(address: "bc1qb", branch: 0, index_at_branch: 1, balance_sats: 40_000_000)
    assert_equal 100_000_000, wallet.balance_sats
    assert_in_delta 1.0, wallet.balance_btc, 1e-9
  end

  test "total_tx_count sums tx_count across addresses" do
    wallet = Wallet.create!(valid_attrs)
    wallet.addresses.create!(address: "bc1qa", branch: 0, index_at_branch: 0, tx_count: 3)
    wallet.addresses.create!(address: "bc1qb", branch: 1, index_at_branch: 0, tx_count: 5)
    assert_equal 8, wallet.total_tx_count
  end

  test "last_synced_at returns the latest address last_synced_at; synced? reflects that" do
    wallet = Wallet.create!(valid_attrs)
    refute wallet.synced?
    older = 2.hours.ago
    newer = 1.minute.ago
    wallet.addresses.create!(address: "bc1qa", branch: 0, index_at_branch: 0, last_synced_at: older)
    wallet.addresses.create!(address: "bc1qb", branch: 0, index_at_branch: 1, last_synced_at: newer)
    assert wallet.synced?
    assert_in_delta newer.to_f, wallet.last_synced_at.to_f, 1
  end

  test "balance_usd is nil when no UsdSnapshot exists" do
    wallet = Wallet.create!(valid_attrs)
    UsdSnapshot.delete_all
    assert_nil wallet.balance_usd
  end

  test "balance_usd uses the latest UsdSnapshot price" do
    wallet = Wallet.create!(valid_attrs)
    wallet.addresses.create!(address: "bc1qa", branch: 0, index_at_branch: 0, balance_sats: 100_000_000)
    UsdSnapshot.delete_all
    UsdSnapshot.create!(captured_on: Date.current - 1, price_usd: 50_000)
    UsdSnapshot.create!(captured_on: Date.current,     price_usd: 80_000)
    assert_equal 80_000.00, wallet.balance_usd
  end
end
