require "test_helper"

class UsdFetcherTest < ActiveSupport::TestCase
  test "returns the BTC/USD price as a BigDecimal on success" do
    HttpStub.with_response(body: '{"bitcoin":{"usd":85432.10}}') do
      price = UsdFetcher.current_price
      assert_kind_of BigDecimal, price
      assert_equal 85432.10.to_d, price
    end
  end

  test "returns nil if the response shape is unexpected" do
    HttpStub.with_response(body: '{"bitcoin":{}}') do
      assert_nil UsdFetcher.current_price
    end
  end

  test "returns nil if the price is not numeric" do
    HttpStub.with_response(body: '{"bitcoin":{"usd":"NaN"}}') do
      assert_nil UsdFetcher.current_price
    end
  end

  test "returns nil on a non-success response" do
    HttpStub.with_response(body: "rate limited", status: 429) do
      assert_nil UsdFetcher.current_price
    end
  end

  test "returns nil on a network exception" do
    HttpStub.with_raise(SocketError) do
      assert_nil UsdFetcher.current_price
    end
  end
end
