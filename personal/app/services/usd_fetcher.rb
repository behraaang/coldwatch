require "net/http"
require "json"

# Fetches the current BTC price in USD from CoinGecko's free API.
# No auth required.
class UsdFetcher
  ENDPOINT = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
  REQUEST_TIMEOUT_SECONDS = 5

  def self.current_price
    uri = URI(ENDPOINT)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: REQUEST_TIMEOUT_SECONDS,
                               read_timeout: REQUEST_TIMEOUT_SECONDS) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "coldwatch/0.1"
      http.request(req)
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    price = data.dig("bitcoin", "usd")
    return nil unless price.is_a?(Numeric)

    price.to_d
  rescue StandardError => e
    Rails.logger.warn("[UsdFetcher] #{e.class}: #{e.message}")
    nil
  end
end
