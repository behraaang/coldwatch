require "net/http"
require "json"

# Synchronously syncs balances and tx counts from mempool.space's REST API
# for every Address belonging to a wallet.
#
# Day 3 implementation: serial HTTPS calls, ~200ms each, ~5-10s total for
# a typical 40-address wallet. Day 4 work moves this to a Sidekiq job and
# replaces serial REST with the WebSocket subscription for live updates.
#
# Errors during a single address fetch are logged and skipped — the rest
# of the wallet still gets synced.
class MempoolFetcher
  BASE_URLS = {
    "mainnet" => "https://mempool.space/api",
    "testnet" => "https://mempool.space/testnet/api"
  }.freeze

  REQUEST_TIMEOUT_SECONDS = 5

  def self.sync_wallet(wallet)
    base = BASE_URLS.fetch(wallet.network) do
      raise ArgumentError, "Unknown network: #{wallet.network}"
    end

    successes = 0
    failures  = []

    wallet.addresses.find_each do |addr|
      data = fetch(addr.address, base: base)
      if data
        addr.update!(
          balance_sats:    data[:balance_sats],
          tx_count:        data[:tx_count],
          last_synced_at:  Time.current
        )
        successes += 1
      else
        failures << addr.address
      end
    end

    { synced: successes, failed: failures }
  end

  def self.fetch(address, base:)
    uri = URI("#{base}/address/#{address}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: REQUEST_TIMEOUT_SECONDS,
                               read_timeout: REQUEST_TIMEOUT_SECONDS) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "coldwatch/0.1 (+https://github.com/behraaang/coldwatch)"
      http.request(req)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    chain   = data["chain_stats"] || {}
    mempool = data["mempool_stats"] || {}

    {
      balance_sats: (chain["funded_txo_sum"].to_i - chain["spent_txo_sum"].to_i) +
                    (mempool["funded_txo_sum"].to_i - mempool["spent_txo_sum"].to_i),
      tx_count:     chain["tx_count"].to_i + mempool["tx_count"].to_i
    }
  rescue StandardError => e
    Rails.logger.warn("[MempoolFetcher] #{address}: #{e.class}: #{e.message}")
    nil
  end

  # Fetch the recent tx list for an address. Returns an Array of tx hashes
  # (in mempool.space's schema: txid, vin[], vout[], status{}) or nil on error.
  # Used by OutgoingTxDetector to classify direction.
  def self.fetch_txs(address, base:)
    uri = URI("#{base}/address/#{address}/txs")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: REQUEST_TIMEOUT_SECONDS,
                               read_timeout: REQUEST_TIMEOUT_SECONDS) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "coldwatch/0.1 (+https://github.com/behraaang/coldwatch)"
      http.request(req)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn("[MempoolFetcher] fetch_txs #{address}: #{e.class}: #{e.message}")
    nil
  end
end
