require "test_helper"

class FeeMonitorJobTest < ActiveJob::TestCase
  setup do
    @wallet = Wallet.create!(
      name:                 "Fee Watch",
      xpub:                 FAKE_ZPUB,
      network:              "mainnet",
      gap_limit:            5,
      ntfy_topic:           "fee_alert_topic_123",
      fee_threshold_sat_vb: 10
    )
  end

  def with_fees(mainnet:, testnet: nil)
    fetcher = ->(network:) {
      case network
      when "mainnet" then mainnet
      when "testnet" then testnet
      end
    }
    FeeFetcher.stub :current, fetcher do
      yield
    end
  end

  test "alerts the wallet when current fastestFee is at or below its threshold" do
    HttpStub.with_response(body: "{}", status: 200) do
      with_fees(mainnet: { fastestFee: 8 }) do
        FeeMonitorJob.new.perform
      end
    end
    assert_not_nil @wallet.reload.last_fee_alert_at,
                   "alerting should stamp last_fee_alert_at"
  end

  test "does not alert when current fastestFee is above the threshold" do
    with_fees(mainnet: { fastestFee: 50 }) do
      FeeMonitorJob.new.perform
    end
    assert_nil @wallet.reload.last_fee_alert_at
  end

  test "respects the 1-hour cooldown" do
    @wallet.update!(last_fee_alert_at: 30.minutes.ago)
    pre = @wallet.reload.last_fee_alert_at
    with_fees(mainnet: { fastestFee: 5 }) do
      FeeMonitorJob.new.perform
    end
    assert_in_delta pre.to_f, @wallet.reload.last_fee_alert_at.to_f, 1,
                    "must not re-stamp within cooldown"
  end

  test "alerts again once the cooldown has elapsed" do
    @wallet.update!(last_fee_alert_at: 2.hours.ago)
    HttpStub.with_response(body: "{}", status: 200) do
      with_fees(mainnet: { fastestFee: 5 }) do
        FeeMonitorJob.new.perform
      end
    end
    assert @wallet.reload.last_fee_alert_at > 1.minute.ago
  end

  test "skips a network with no wallets configured for fee alerts" do
    fetched = []
    FeeFetcher.stub :current, ->(network:) { fetched << network; nil } do
      FeeMonitorJob.new.perform
    end
    refute_includes fetched, "testnet",
                    "must not call FeeFetcher for a network with no eligible wallets"
  end

  test "always self-reschedules, even when the body work raises" do
    FeeFetcher.stub :current, ->(network:) { raise "boom" } do
      assert_raises(RuntimeError) { FeeMonitorJob.new.perform }
    end
    assert_enqueued_with(job: FeeMonitorJob)
  end

  test "self-reschedules on a clean run" do
    with_fees(mainnet: { fastestFee: 50 }) do
      FeeMonitorJob.new.perform
    end
    assert_enqueued_with(job: FeeMonitorJob)
  end
end
