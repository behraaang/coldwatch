require "test_helper"

class UsdSnapshotTest < ActiveSupport::TestCase
  setup { UsdSnapshot.delete_all }

  test "is valid with required attrs" do
    assert UsdSnapshot.new(captured_on: Date.current, price_usd: 70_000).valid?
  end

  test "requires captured_on" do
    refute UsdSnapshot.new(price_usd: 70_000).valid?
  end

  test "requires price_usd to be positive" do
    refute UsdSnapshot.new(captured_on: Date.current, price_usd: 0).valid?
    refute UsdSnapshot.new(captured_on: Date.current, price_usd: -1).valid?
  end

  test "captured_on is unique" do
    today = Date.current
    UsdSnapshot.create!(captured_on: today, price_usd: 60_000)
    dup = UsdSnapshot.new(captured_on: today, price_usd: 60_001)
    refute dup.valid?
    assert_includes dup.errors[:captured_on], "has already been taken"
  end

  test ".latest returns the most recent snapshot" do
    older = UsdSnapshot.create!(captured_on: Date.current - 2, price_usd: 50_000)
    newer = UsdSnapshot.create!(captured_on: Date.current,     price_usd: 80_000)
    assert_equal newer, UsdSnapshot.latest
    refute_equal older, UsdSnapshot.latest
  end

  test ".latest_price returns the latest price or nil when empty" do
    assert_nil UsdSnapshot.latest_price
    UsdSnapshot.create!(captured_on: Date.current, price_usd: 80_000)
    assert_equal 80_000.to_d, UsdSnapshot.latest_price
  end
end
