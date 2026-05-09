# Daily USD-per-BTC snapshot job. Self-reschedules to run once a day at
# 00:30 UTC. Idempotent — uses upsert_all so a same-day re-run just
# refreshes the price.
class UsdSnapshotJob < ApplicationJob
  queue_as :default

  def perform
    price = UsdFetcher.current_price
    if price
      UsdSnapshot.upsert_all(
        [{
          captured_on: Date.current,
          price_usd:   price,
          source:      "coingecko",
          created_at:  Time.current,
          updated_at:  Time.current
        }],
        unique_by: :captured_on
      )
      Rails.logger.info("[UsdSnapshotJob] snapshot #{Date.current} = $#{price}")
    else
      Rails.logger.warn("[UsdSnapshotJob] fetch failed, skipping today's snapshot")
    end
  ensure
    next_run = (Date.current + 1).beginning_of_day + 30.minutes
    self.class.set(wait_until: next_run).perform_later
  end
end
