require "test_helper"

# Uses the BIP84 spec test vector zpub. The expected addresses below are
# the canonical first three derived addresses for the mnemonic
#   "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
# at m/84'/0'/0' — published in BIP84 itself.
class AddressDerivationTest < ActiveSupport::TestCase
  ZPUB              = BIP84_VECTORS["mainnet_zpub"]
  FIRST_RECEIVE     = BIP84_VECTORS["mainnet_first_receive"]
  SECOND_RECEIVE    = BIP84_VECTORS["mainnet_second_receive"]
  FIRST_CHANGE      = BIP84_VECTORS["mainnet_first_change"]

  test "derive_one matches the BIP84 spec test vector for m/0/0" do
    addr = AddressDerivation.derive_one(xpub: ZPUB, network: "mainnet", branch: 0, index: 0)
    assert_equal FIRST_RECEIVE, addr
  end

  test "derive_one matches the BIP84 spec test vector for m/0/1" do
    addr = AddressDerivation.derive_one(xpub: ZPUB, network: "mainnet", branch: 0, index: 1)
    assert_equal SECOND_RECEIVE, addr
  end

  test "derive_one matches the BIP84 spec test vector for m/1/0 (change)" do
    addr = AddressDerivation.derive_one(xpub: ZPUB, network: "mainnet", branch: 1, index: 0)
    assert_equal FIRST_CHANGE, addr
  end

  test "materialize_all creates 2 * gap_limit rows on first run" do
    wallet = Wallet.create!(name: "BIP84 Test", xpub: ZPUB, network: "mainnet", gap_limit: 3)
    AddressDerivation.materialize_all(wallet)
    assert_equal 6, wallet.addresses.count
    assert_equal 3, wallet.addresses.receive.count
    assert_equal 3, wallet.addresses.change.count
  end

  test "materialize_all is idempotent — second run does not duplicate" do
    wallet = Wallet.create!(name: "BIP84 Idempotent", xpub: ZPUB, network: "mainnet", gap_limit: 4)
    AddressDerivation.materialize_all(wallet)
    AddressDerivation.materialize_all(wallet)
    assert_equal 8, wallet.addresses.count
  end

  test "materialize_all writes the canonical first receive address" do
    wallet = Wallet.create!(name: "BIP84 First Recv", xpub: ZPUB, network: "mainnet", gap_limit: 2)
    AddressDerivation.materialize_all(wallet)
    first_recv = wallet.addresses.find_by(branch: 0, index_at_branch: 0)
    assert_equal FIRST_RECEIVE, first_recv.address
  end
end
