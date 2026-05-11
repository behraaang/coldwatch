require "test_helper"
require "csv"

class WalletCsvExporterTest < ActiveSupport::TestCase
  setup do
    @wallet = Wallet.create!(name: "Export W", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5)
    @address = @wallet.addresses.create!(address: "bc1qexp", branch: 0, index_at_branch: 0,
                                         balance_sats: 75_000, tx_count: 2)
    @utxo = @address.utxos.create!(txid: "a" * 64, vout: 0, value_sats: 60_000, confirmed: true,
                                   block_height: 880_000)
    @event = @wallet.alert_events.create!(txid: "b" * 64, direction: "outgoing",
                                          amount_sats: 25_000, confirmed: false)
  end

  test "header block reports wallet metadata but never the xpub" do
    csv = WalletCsvExporter.call(@wallet)
    assert_includes csv, "# coldwatch wallet export"
    assert_includes csv, "Export W"
    assert_includes csv, "mainnet"
    refute_includes csv, FAKE_ZPUB
    refute_includes csv, @wallet.xpub
  end

  test "addresses section lists every address with derivation + balances" do
    csv = WalletCsvExporter.call(@wallet)
    rows = CSV.parse(csv)
    addresses_header_idx = rows.index { |r| r.first == "## addresses" }
    assert addresses_header_idx
    body = rows[(addresses_header_idx + 2)..].take_while { |r| r.any? && !r.first.to_s.start_with?("##") }
    assert(body.any? { |r| r.include?("bc1qexp") })
  end

  test "utxos section lists each utxo with its address" do
    csv = WalletCsvExporter.call(@wallet)
    assert_includes csv, "## utxos"
    assert_includes csv, "a" * 64
    assert_includes csv, "bc1qexp"
    assert_includes csv, "60000"
  end

  test "alarm events section lists each event" do
    csv = WalletCsvExporter.call(@wallet)
    assert_includes csv, "## alarm events"
    assert_includes csv, "b" * 64
    assert_includes csv, "outgoing"
  end

  test "parses cleanly as CSV (Excel-readable, no malformed rows)" do
    csv = WalletCsvExporter.call(@wallet)
    assert_nothing_raised { CSV.parse(csv) }
  end
end
