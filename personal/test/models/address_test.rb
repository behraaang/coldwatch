require "test_helper"

class AddressTest < ActiveSupport::TestCase
  setup do
    @wallet = Wallet.create!(
      name: "Address Owner", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5
    )
  end

  def attrs(overrides = {})
    { wallet: @wallet, address: "bc1qaddrtest1", branch: 0, index_at_branch: 0 }.merge(overrides)
  end

  test "is valid with required attrs" do
    assert Address.new(attrs).valid?
  end

  test "requires the address string" do
    refute Address.new(attrs(address: nil)).valid?
  end

  test "address must be globally unique" do
    Address.create!(attrs)
    dup = Address.new(attrs(index_at_branch: 1))
    refute dup.valid?
    assert_includes dup.errors[:address], "has already been taken"
  end

  test "branch must be 0 (receive) or 1 (change)" do
    refute Address.new(attrs(branch: 2)).valid?
    refute Address.new(attrs(branch: -1)).valid?
    assert Address.new(attrs(branch: 0)).valid?
    assert Address.new(attrs(address: "bc1qaddrtest2", branch: 1)).valid?
  end

  test "index_at_branch must be a non-negative integer" do
    refute Address.new(attrs(index_at_branch: -1)).valid?
    refute Address.new(attrs(index_at_branch: 1.5)).valid?
    assert Address.new(attrs(index_at_branch: 0)).valid?
  end

  test "receive? / change? mirror the branch" do
    receive = Address.new(attrs)
    change  = Address.new(attrs(address: "bc1qaddrtest2", branch: 1))
    assert receive.receive?
    refute receive.change?
    assert change.change?
    refute change.receive?
  end

  test "derivation_path concatenates branch and index" do
    a = Address.new(attrs(branch: 1, index_at_branch: 7))
    assert_equal "m/1/7", a.derivation_path
  end

  test "balance_btc converts sats to BTC" do
    a = Address.new(attrs(balance_sats: 25_000_000))
    assert_in_delta 0.25, a.balance_btc, 1e-9
  end

  test "ordered scope sorts by branch then index" do
    Address.create!(attrs(address: "bc1q1", branch: 1, index_at_branch: 0))
    Address.create!(attrs(address: "bc1q0", branch: 0, index_at_branch: 5))
    Address.create!(attrs(address: "bc1q2", branch: 0, index_at_branch: 1))
    expected = [[0, 1], [0, 5], [1, 0]]
    actual = @wallet.addresses.ordered.pluck(:branch, :index_at_branch)
    assert_equal expected, actual
  end

  test "used / unused scopes split on tx_count" do
    used   = Address.create!(attrs(address: "bc1qused",   tx_count: 1))
    unused = Address.create!(attrs(address: "bc1qunused", index_at_branch: 1, tx_count: 0))
    assert_includes Address.used,   used
    assert_includes Address.unused, unused
    refute_includes Address.used,   unused
    refute_includes Address.unused, used
  end
end
