require "test_helper"

class UsdSnapshotJobTest < ActiveJob::TestCase
  setup { UsdSnapshot.delete_all }

  test "upserts today's snapshot when fetcher returns a price" do
    UsdFetcher.stub :current_price, 75_500.to_d do
      UsdSnapshotJob.new.perform
    end
    snap = UsdSnapshot.find_by(captured_on: Date.current)
    assert_not_nil snap
    assert_equal 75_500.to_d, snap.price_usd
    assert_equal "coingecko", snap.source
  end

  test "is idempotent — running twice on the same date keeps a single row" do
    UsdFetcher.stub :current_price, 70_000.to_d do
      UsdSnapshotJob.new.perform
    end
    UsdFetcher.stub :current_price, 71_000.to_d do
      UsdSnapshotJob.new.perform
    end
    assert_equal 1, UsdSnapshot.where(captured_on: Date.current).count
    assert_equal 71_000.to_d, UsdSnapshot.find_by(captured_on: Date.current).price_usd
  end

  test "skips persistence when the fetcher returns nil" do
    UsdFetcher.stub :current_price, nil do
      UsdSnapshotJob.new.perform
    end
    assert_equal 0, UsdSnapshot.where(captured_on: Date.current).count
  end

  test "always self-reschedules" do
    UsdFetcher.stub :current_price, 70_000.to_d do
      UsdSnapshotJob.new.perform
    end
    assert_enqueued_with(job: UsdSnapshotJob)
  end
end
