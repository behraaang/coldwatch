require "test_helper"

class AlertEventTest < ActiveSupport::TestCase
  setup do
    @wallet = Wallet.create!(
      name: "Alert Owner", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5
    )
  end

  def attrs(overrides = {})
    {
      wallet:      @wallet,
      txid:        "abcdef" * 10 + "1234",
      direction:   "outgoing",
      amount_sats: 250_000,
      confirmed:   false
    }.merge(overrides)
  end

  test "is valid with required attrs" do
    assert AlertEvent.new(attrs).valid?
  end

  test "requires a txid" do
    refute AlertEvent.new(attrs(txid: nil)).valid?
  end

  test "(wallet, txid) is unique — same txid in another wallet is allowed" do
    AlertEvent.create!(attrs)
    dup = AlertEvent.new(attrs)
    refute dup.valid?

    other_wallet = Wallet.create!(
      name: "Other Wallet", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5
    )
    assert AlertEvent.new(attrs(wallet: other_wallet)).valid?
  end

  test "direction must be outgoing or incoming" do
    refute AlertEvent.new(attrs(direction: "sideways")).valid?
    assert AlertEvent.new(attrs(direction: "outgoing")).valid?
    assert AlertEvent.new(attrs(direction: "incoming", txid: "z" * 64)).valid?
  end

  test "amount_btc divides amount_sats by 1e8 and tolerates nil" do
    assert_in_delta 0.0025, AlertEvent.new(attrs).amount_btc, 1e-9
    assert_nil AlertEvent.new(attrs(amount_sats: nil)).amount_btc
  end

  test "short_txid is first 8 + ellipsis + last 6" do
    e = AlertEvent.new(attrs(txid: "0123456789abcdef" * 4))
    assert_equal "01234567…abcdef", e.short_txid
  end

  test "mempool_url builds a mempool.space tx link" do
    e = AlertEvent.new(attrs(txid: "deadbeef"))
    assert_equal "https://mempool.space/tx/deadbeef", e.mempool_url
  end

  test "scopes filter on direction and dispatched_at" do
    out = AlertEvent.create!(attrs(txid: "out" + "f" * 60, direction: "outgoing"))
    inc = AlertEvent.create!(attrs(txid: "inc" + "f" * 60, direction: "incoming"))
    sent = AlertEvent.create!(attrs(txid: "sent" + "f" * 59, dispatched_at: Time.current))

    assert_includes AlertEvent.outgoing,   out
    refute_includes AlertEvent.outgoing,   inc
    assert_includes AlertEvent.incoming,   inc
    assert_includes AlertEvent.dispatched, sent
    refute_includes AlertEvent.dispatched, out
  end
end
