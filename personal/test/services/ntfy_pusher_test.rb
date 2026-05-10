require "test_helper"

class NtfyPusherTest < ActiveSupport::TestCase
  setup do
    @wallet = Wallet.create!(
      name:       "Ntfy Wallet",
      xpub:       FAKE_ZPUB,
      network:    "mainnet",
      gap_limit:  5,
      ntfy_topic: "secret_topic_for_test_1"
    )
    @event = AlertEvent.create!(
      wallet:       @wallet,
      txid:         "deadbeef" * 8,
      direction:    "outgoing",
      amount_sats:  150_000,
      confirmed:    false
    )
  end

  test "dispatch returns false when wallet has no ntfy_topic" do
    @wallet.update!(ntfy_topic: nil)
    refute NtfyPusher.dispatch(@event)
    assert_nil @event.reload.dispatched_at
  end

  test "dispatch posts to ntfy.sh and stamps dispatched_at on success" do
    HttpStub.with_response(body: "{}", status: 200) do
      assert NtfyPusher.dispatch(@event)
    end
    assert_not_nil @event.reload.dispatched_at
  end

  test "dispatch returns false on a non-success ntfy response" do
    HttpStub.with_response(body: "rate limited", status: 429) do
      refute NtfyPusher.dispatch(@event)
    end
    assert_nil @event.reload.dispatched_at
  end

  test "dispatch returns false on a network exception" do
    HttpStub.with_raise(Errno::ETIMEDOUT, message: "timeout") do
      refute NtfyPusher.dispatch(@event)
    end
  end

  test "build_body includes amount, wallet name, txid, mempool URL, and confirmation state" do
    body = NtfyPusher.build_body(@event)
    assert_includes body, "Outgoing 0.0015 BTC"
    assert_includes body, "Ntfy Wallet"
    assert_includes body, @event.short_txid
    assert_includes body, "unconfirmed (mempool)"
    assert_includes body, @event.mempool_url
  end

  test "build_body shows the block height when confirmed" do
    @event.update!(confirmed: true, block_height: 880_000)
    body = NtfyPusher.build_body(@event)
    assert_includes body, "confirmed at block 880000"
  end

  test "build_body says unknown amount when amount_sats is nil" do
    @event.update!(amount_sats: nil)
    body = NtfyPusher.build_body(@event)
    assert_includes body, "unknown amount"
  end

  test "build_headers sets urgent priority and a click URL" do
    headers = NtfyPusher.build_headers(@event)
    assert_equal "urgent", headers["Priority"]
    assert_equal @event.mempool_url, headers["Click"]
    assert_match(/coldwatch ALARM/, headers["Title"])
  end
end
