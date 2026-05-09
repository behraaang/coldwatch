# Periodic fee-window monitor. For every wallet that has a fee_threshold_sat_vb
# set AND a ntfy_topic, checks the current fastestFee from mempool.space.
# If below threshold AND we haven't pushed a fee alert in the last hour,
# fire an ntfy push so the user can broadcast cheap consolidations.
#
# Self-reschedules every 5 minutes (poor-man's cron without sidekiq-cron gem).
class FeeMonitorJob < ApplicationJob
  queue_as :default

  CHECK_INTERVAL = 5.minutes
  ALERT_COOLDOWN = 1.hour

  def perform
    %w[mainnet testnet].each do |network|
      next if Wallet.where(network: network).where.not(fee_threshold_sat_vb: nil).none?

      fees = FeeFetcher.current(network: network)
      next if fees.nil?

      current_sat_vb = fees[:fastestFee] || fees[:halfHourFee]
      next if current_sat_vb.nil?

      Rails.logger.info("[FeeMonitorJob] #{network} fastestFee=#{current_sat_vb} sat/vB")

      eligible = Wallet.where(network: network)
                       .where("fee_threshold_sat_vb >= ?", current_sat_vb)
                       .where.not(ntfy_topic: nil)

      eligible.find_each do |wallet|
        next if wallet.last_fee_alert_at && wallet.last_fee_alert_at > ALERT_COOLDOWN.ago

        send_alert(wallet, current_sat_vb)
        wallet.update!(last_fee_alert_at: Time.current)
      end
    end
  ensure
    self.class.set(wait: CHECK_INTERVAL).perform_later
  end

  private

  def send_alert(wallet, sat_vb)
    return if wallet.ntfy_topic.blank?

    body = "Mempool fees just dropped to #{sat_vb} sat/vB on #{wallet.network}.\n" \
           "Threshold for #{wallet.name}: #{wallet.fee_threshold_sat_vb} sat/vB.\n" \
           "Good window to consolidate UTXOs or broadcast queued spends.\n" \
           "https://mempool.space"

    headers = {
      "Title"        => "🟢 coldwatch fee window",
      "Priority"     => "default",
      "Tags"         => "money_with_wings,bitcoin",
      "Click"        => "https://mempool.space",
      "Content-Type" => "text/plain; charset=utf-8"
    }

    uri = URI("#{NtfyPusher::NTFY_BASE}/#{wallet.ntfy_topic}")
    req = Net::HTTP::Post.new(uri)
    headers.each { |k, v| req[k] = v }
    req["User-Agent"] = "coldwatch/0.1"
    req.body = body

    Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                    open_timeout: 5, read_timeout: 5) do |http|
      response = http.request(req)
      Rails.logger.info("[FeeMonitorJob] alert #{wallet.name}: #{response.code}")
    end
  rescue StandardError => e
    Rails.logger.error("[FeeMonitorJob] alert failed: #{e.class}: #{e.message}")
  end
end
