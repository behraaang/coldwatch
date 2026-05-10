require "test_helper"

class FeeFetcherTest < ActiveSupport::TestCase
  test "returns parsed fee tiers as a hash with symbol keys" do
    body = { fastestFee: 12, halfHourFee: 8, hourFee: 5, economyFee: 2, minimumFee: 1 }.to_json
    HttpStub.with_response(body: body) do
      result = FeeFetcher.current(network: "mainnet")
      assert_equal 12, result[:fastestFee]
      assert_equal 8,  result[:halfHourFee]
      assert_equal 1,  result[:minimumFee]
    end
  end

  test "returns nil for an unknown network without making an HTTP call" do
    # If this hit the network it would explode in CI. The early-return guards us.
    assert_nil FeeFetcher.current(network: "regtest")
  end

  test "returns nil on a non-success response" do
    HttpStub.with_response(body: "boom", status: 502) do
      assert_nil FeeFetcher.current(network: "mainnet")
    end
  end

  test "returns nil and logs on a network exception" do
    HttpStub.with_raise(Errno::ECONNRESET) do
      assert_nil FeeFetcher.current(network: "mainnet")
    end
  end

  test "returns nil on invalid JSON" do
    HttpStub.with_response(body: "not json {{") do
      assert_nil FeeFetcher.current(network: "mainnet")
    end
  end
end
