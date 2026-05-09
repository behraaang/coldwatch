require "net/http"
require "uri"

# Pushes an alarm to the user's phone via ntfy.sh.
#
# Day 5 MVP: plaintext payload with the txid + amount + mempool link.
# The wallet's `ntfy_topic` is the shared secret with the phone subscriber.
#
# Future hardening (Day 6+):
#   - End-to-end encryption (ntfy supports its own E2E scheme; we'd encrypt
#     the body client-side before POST)
#   - HMAC signature in a header for spoof detection
#   - Heartbeat: if delivery fails N times in a row, fall back to email
class NtfyPusher
  NTFY_BASE = "https://ntfy.sh"
  REQUEST_TIMEOUT_SECONDS = 5

  def self.dispatch(alert_event)
    wallet = alert_event.wallet
    topic  = wallet.ntfy_topic
    return false if topic.blank?

    body    = build_body(alert_event)
    headers = build_headers(alert_event)

    uri = URI("#{NTFY_BASE}/#{topic}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: REQUEST_TIMEOUT_SECONDS,
                               read_timeout: REQUEST_TIMEOUT_SECONDS) do |http|
      req = Net::HTTP::Post.new(uri)
      headers.each { |k, v| req[k] = v }
      req["User-Agent"] = "coldwatch/0.1"
      req.body = body
      http.request(req)
    end

    if response.is_a?(Net::HTTPSuccess)
      alert_event.update!(dispatched_at: Time.current)
      Rails.logger.info("[NtfyPusher] dispatched #{alert_event.txid} → topic #{topic[0..7]}…")
      true
    else
      Rails.logger.error("[NtfyPusher] failed #{response.code}: #{response.body.to_s[0..200]}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("[NtfyPusher] #{e.class}: #{e.message}")
    false
  end

  def self.build_body(alert_event)
    btc = alert_event.amount_btc
    amount_str = btc ? "#{format('%.8f', btc).sub(/0+$/, '').sub(/\.$/, '.0')} BTC" : "unknown amount"

    [
      "Outgoing #{amount_str} on #{alert_event.wallet.name}.",
      "txid: #{alert_event.short_txid}",
      alert_event.confirmed ? "confirmed at block #{alert_event.block_height}" : "unconfirmed (mempool)",
      alert_event.mempool_url
    ].join("\n")
  end

  def self.build_headers(alert_event)
    {
      "Title"        => "⚠ coldwatch ALARM",
      "Priority"     => "urgent",
      "Tags"         => "rotating_light,bitcoin,warning",
      "Click"        => alert_event.mempool_url,
      "Content-Type" => "text/plain; charset=utf-8"
    }
  end
end
