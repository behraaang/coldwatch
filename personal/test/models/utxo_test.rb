require "test_helper"

class UtxoTest < ActiveSupport::TestCase
  setup do
    @wallet = Wallet.create!(
      name: "Utxo Owner", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5
    )
    @address = @wallet.addresses.create!(address: "bc1qutxotest", branch: 0, index_at_branch: 0)
  end

  def attrs(overrides = {})
    {
      address:    @address,
      txid:       "a" * 64,
      vout:       0,
      value_sats: 100_000,
      confirmed:  true
    }.merge(overrides)
  end

  test "is valid with required attrs" do
    assert Utxo.new(attrs).valid?
  end

  test "requires txid" do
    refute Utxo.new(attrs(txid: nil)).valid?
  end

  test "requires vout to be a non-negative integer" do
    refute Utxo.new(attrs(vout: nil)).valid?
    refute Utxo.new(attrs(vout: -1)).valid?
    assert Utxo.new(attrs(vout: 0)).valid?
  end

  test "value_sats must be a positive integer" do
    refute Utxo.new(attrs(value_sats: 0)).valid?
    refute Utxo.new(attrs(value_sats: -1)).valid?
    assert Utxo.new(attrs(value_sats: 1)).valid?
  end

  test "(txid, vout) pair must be unique" do
    Utxo.create!(attrs)
    dup = Utxo.new(attrs)
    refute dup.valid?
    assert_includes dup.errors[:txid], "has already been taken"

    # Same txid with a different vout is allowed.
    assert Utxo.new(attrs(vout: 1)).valid?
  end

  test "dust? and dust scope use DUST_THRESHOLD_SATS" do
    dust  = Utxo.create!(attrs(value_sats: Utxo::DUST_THRESHOLD_SATS - 1))
    fat   = Utxo.create!(attrs(txid: "b" * 64, value_sats: Utxo::DUST_THRESHOLD_SATS))
    assert dust.dust?
    refute fat.dust?
    assert_includes Utxo.dust, dust
    refute_includes Utxo.dust, fat
    assert_includes Utxo.nondust, fat
  end

  test "by_value sorts descending" do
    small = Utxo.create!(attrs(txid: "c" * 64, value_sats: 10_000))
    big   = Utxo.create!(attrs(txid: "d" * 64, value_sats: 99_000_000))
    assert_equal [big, small], Utxo.by_value.where(id: [big.id, small.id]).to_a
  end

  test "value_btc divides by 1e8" do
    u = Utxo.new(attrs(value_sats: 50_000_000))
    assert_in_delta 0.5, u.value_btc, 1e-9
  end

  test "short_txid is first 6 + ellipsis + last 4" do
    u = Utxo.new(attrs(txid: "abcdef0123456789" * 4))
    assert_equal "abcdef…6789", u.short_txid
  end

  test "confirmed / unconfirmed scopes split on the boolean" do
    confirmed   = Utxo.create!(attrs(txid: "e" * 64, confirmed: true))
    unconfirmed = Utxo.create!(attrs(txid: "f" * 64, confirmed: false))
    assert_includes Utxo.confirmed,   confirmed
    assert_includes Utxo.unconfirmed, unconfirmed
  end
end
