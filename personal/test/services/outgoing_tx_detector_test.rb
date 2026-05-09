require "test_helper"

class OutgoingTxDetectorTest < ActiveSupport::TestCase
  OUR_ADDRS = ["bc1qour1", "bc1qour2", "bc1qour3"].to_set
  EXTERNAL_ADDR = "bc1qexternal"

  def make_tx(vin_addrs:, vout_addrs:, vin_values: nil, vout_values: nil, txid: "abc123", confirmed: true)
    {
      "txid" => txid,
      "vin"  => vin_addrs.each_with_index.map do |a, i|
        { "prevout" => { "scriptpubkey_address" => a, "value" => (vin_values && vin_values[i]) || 100_000 } }
      end,
      "vout" => vout_addrs.each_with_index.map do |a, i|
        { "scriptpubkey_address" => a, "value" => (vout_values && vout_values[i]) || 50_000 }
      end,
      "status" => { "confirmed" => confirmed, "block_height" => 879_431 }
    }
  end

  test "classifies as outgoing when any input is one of our addresses" do
    tx = make_tx(vin_addrs: ["bc1qour1"], vout_addrs: [EXTERNAL_ADDR])
    assert_equal "outgoing", OutgoingTxDetector.classify(tx, OUR_ADDRS)
  end

  test "classifies as incoming when no inputs are ours but an output is" do
    tx = make_tx(vin_addrs: [EXTERNAL_ADDR], vout_addrs: ["bc1qour2"])
    assert_equal "incoming", OutgoingTxDetector.classify(tx, OUR_ADDRS)
  end

  test "classifies as outgoing when there is change back to us" do
    # Outgoing tx that sends to external + change back to one of our change addresses
    tx = make_tx(vin_addrs: ["bc1qour1"], vout_addrs: [EXTERNAL_ADDR, "bc1qour3"])
    assert_equal "outgoing", OutgoingTxDetector.classify(tx, OUR_ADDRS)
  end

  test "classifies as unrelated when neither inputs nor outputs are ours" do
    tx = make_tx(vin_addrs: [EXTERNAL_ADDR], vout_addrs: ["bc1qotherperson"])
    assert_equal "unrelated", OutgoingTxDetector.classify(tx, OUR_ADDRS)
  end

  test "outgoing_amount_sats returns net amount sent away (spent minus change)" do
    tx = make_tx(
      vin_addrs:   ["bc1qour1"],
      vin_values:  [1_000_000],
      vout_addrs:  [EXTERNAL_ADDR, "bc1qour3"],
      vout_values: [600_000, 350_000]   # 50k goes to fees
    )
    # Spent 1_000_000 from us, 350_000 came back as change → net out = 650_000
    assert_equal 650_000, OutgoingTxDetector.outgoing_amount_sats(tx, OUR_ADDRS)
  end

  test "outgoing_amount_sats handles malformed input gracefully" do
    tx = { "vin" => nil, "vout" => nil }
    assert_equal 0, OutgoingTxDetector.outgoing_amount_sats(tx, OUR_ADDRS)
  end

  test "classify handles missing prevout gracefully" do
    tx = { "vin" => [{ "prevout" => nil }], "vout" => [{ "scriptpubkey_address" => "bc1qour1" }] }
    assert_equal "incoming", OutgoingTxDetector.classify(tx, OUR_ADDRS)
  end
end
