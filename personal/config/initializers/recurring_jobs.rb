# Bootstrap the periodic jobs once per process.
#
# FeeMonitorJob and UsdSnapshotJob self-reschedule on completion, but
# they need to be enqueued at least once. Web, sidekiq, and the
# mempool_subscriber container all load this initializer; a Redis SETNX
# lock makes sure exactly one of them does the bootstrap.
#
# Opt-in via ENV var so the bootstrap doesn't run during tests, console,
# or one-off rake tasks. Set BOOTSTRAP_RECURRING_JOBS=true on the sidekiq
# container in compose for production.
Rails.application.config.after_initialize do
  next if Rails.env.test?
  next unless ENV["BOOTSTRAP_RECURRING_JOBS"] == "true"

  begin
    Sidekiq.redis do |conn|
      if conn.set("coldwatch:cron:bootstrap", Time.current.to_i, nx: true, ex: 60)
        Rails.logger.info("[recurring_jobs] bootstrapping FeeMonitorJob + UsdSnapshotJob")
        FeeMonitorJob.perform_later
        UsdSnapshotJob.perform_later
      else
        Rails.logger.info("[recurring_jobs] another process already bootstrapped")
      end
    end
  rescue StandardError => e
    Rails.logger.warn("[recurring_jobs] bootstrap skipped: #{e.class}: #{e.message}")
  end
end
