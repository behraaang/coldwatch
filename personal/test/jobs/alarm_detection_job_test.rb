require "test_helper"

class AlarmDetectionJobTest < ActiveJob::TestCase
  setup do
    @wallet  = Wallet.create!(name: "Alarm W", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5)
    @address = @wallet.addresses.create!(address: "bc1qalarm", branch: 0, index_at_branch: 0)
  end

  test "delegates to OutgoingTxDetector.process for the address" do
    captured = nil
    OutgoingTxDetector.stub :process, ->(addr) { captured = addr; [] } do
      AlarmDetectionJob.new.perform(@address.id)
    end
    assert_equal @address, captured
  end

  test "no-ops when the address has been deleted before the job runs" do
    deleted_id = @address.id
    @address.destroy!
    called = false
    OutgoingTxDetector.stub :process, ->(_) { called = true; [] } do
      AlarmDetectionJob.new.perform(deleted_id)
    end
    refute called, "process must not run for a missing address"
  end
end
