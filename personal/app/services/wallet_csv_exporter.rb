require "csv"

# Builds a single CSV string capturing everything that's safe to share
# about a wallet — addresses, UTXOs, alarm history — for spouse/heir
# handoff or tax bookkeeping. Watch-only: the xpub is NOT included.
#
# Output is one file with three sections separated by blank rows.
# Each section starts with its own header row so Excel / Numbers / Sheets
# can read it as-is without preprocessing.
class WalletCsvExporter
  def self.call(wallet)
    CSV.generate do |csv|
      header(csv, wallet)
      csv << []

      addresses_section(csv, wallet)
      csv << []

      utxos_section(csv, wallet)
      csv << []

      alert_events_section(csv, wallet)
    end
  end

  def self.header(csv, wallet)
    csv << ["# coldwatch wallet export"]
    csv << ["Wallet",          wallet.name]
    csv << ["Network",         wallet.network]
    csv << ["Gap limit",       wallet.gap_limit]
    csv << ["Balance (BTC)",   format("%.8f", wallet.balance_btc)]
    csv << ["Balance (sats)",  wallet.balance_sats]
    csv << ["Total tx count",  wallet.total_tx_count]
    csv << ["Last synced at",  wallet.last_synced_at&.iso8601]
    csv << ["Exported at",     Time.current.iso8601]
  end

  def self.addresses_section(csv, wallet)
    csv << ["## addresses"]
    csv << %w[derivation_path branch index address balance_sats balance_btc tx_count last_synced_at]
    wallet.addresses.ordered.find_each do |a|
      csv << [
        a.derivation_path,
        a.receive? ? "receive" : "change",
        a.index_at_branch,
        a.address,
        a.balance_sats,
        format("%.8f", a.balance_btc),
        a.tx_count,
        a.last_synced_at&.iso8601
      ]
    end
  end

  def self.utxos_section(csv, wallet)
    csv << ["## utxos"]
    csv << %w[txid vout address value_sats value_btc confirmed block_height fetched_at]
    wallet.utxos.includes(:address).by_value.find_each do |u|
      csv << [
        u.txid,
        u.vout,
        u.address.address,
        u.value_sats,
        format("%.8f", u.value_btc),
        u.confirmed,
        u.block_height,
        u.fetched_at&.iso8601
      ]
    end
  end

  def self.alert_events_section(csv, wallet)
    csv << ["## alarm events"]
    csv << %w[created_at txid direction amount_sats amount_btc confirmed block_height dispatched_at]
    wallet.alert_events.recent.find_each do |e|
      csv << [
        e.created_at.iso8601,
        e.txid,
        e.direction,
        e.amount_sats,
        e.amount_btc && format("%.8f", e.amount_btc),
        e.confirmed,
        e.block_height,
        e.dispatched_at&.iso8601
      ]
    end
  end
end
