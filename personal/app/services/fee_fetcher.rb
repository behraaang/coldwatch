require "net/http"
require "json"

# Fetches the current mempool.space recommended-fee tiers.
# Returns a hash like { fastestFee:, halfHourFee:, hourFee:, economyFee:, minimumFee: }
# (sat/vB) or nil on error.
class FeeFetcher
  ENDPOINTS = {
    "mainnet" => "https://mempool.space/api/v1/fees/recommended",
    "testnet" => "https://mempool.space/testnet/api/v1/fees/recommended"
  }.freeze

  REQUEST_TIMEOUT_SECONDS = 5

  def self.current(network: "mainnet")
    url = ENDPOINTS.fetch(network) { return nil }
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: REQUEST_TIMEOUT_SECONDS,
                               read_timeout: REQUEST_TIMEOUT_SECONDS) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "coldwatch/0.1"
      http.request(req)
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).symbolize_keys
  rescue StandardError => e
    Rails.logger.warn("[FeeFetcher] #{e.class}: #{e.message}")
    nil
  end
end
