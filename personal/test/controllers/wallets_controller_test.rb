require "test_helper"

class WalletsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @wallet = Wallet.create!(name: "Existing", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 5)
  end

  test "GET /wallets renders the index" do
    get wallets_path
    assert_response :success
  end

  test "GET /wallets/new renders the form" do
    get new_wallet_path
    assert_response :success
  end

  test "GET /wallets/:id renders the show page" do
    get wallet_path(@wallet)
    assert_response :success
  end

  test "GET /wallets/:id renders show even when wallet has a fee_threshold (FeeFetcher stubbed)" do
    @wallet.update!(fee_threshold_sat_vb: 8, ntfy_topic: "topic_aaaaaaaa")
    FeeFetcher.stub :current, { fastestFee: 5, halfHourFee: 4, hourFee: 3, economyFee: 2, minimumFee: 1 } do
      get wallet_path(@wallet)
    end
    assert_response :success
  end

  test "POST /wallets with valid params creates the wallet and enqueues a sync" do
    assert_enqueued_with(job: WalletSyncJob) do
      assert_difference -> { Wallet.count }, 1 do
        post wallets_path, params: {
          wallet: {
            name:      "Brand New",
            xpub:      FAKE_ZPUB,
            network:   "mainnet",
            gap_limit: 10
          }
        }
      end
    end
    assert_redirected_to wallet_path(Wallet.find_by(name: "Brand New"))
  end

  test "POST /wallets with invalid params re-renders new with 422" do
    assert_no_difference -> { Wallet.count } do
      post wallets_path, params: {
        wallet: { name: "", xpub: FAKE_ZPUB, network: "mainnet", gap_limit: 10 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "POST /wallets rejects a mismatched xpub/network combo" do
    assert_no_difference -> { Wallet.count } do
      post wallets_path, params: {
        wallet: { name: "Mismatched", xpub: FAKE_VPUB, network: "mainnet", gap_limit: 10 }
      }
    end
    assert_response :unprocessable_entity
  end

  test "POST /wallets/:id/sync enqueues a sync and redirects" do
    assert_enqueued_with(job: WalletSyncJob) do
      post sync_wallet_path(@wallet)
    end
    assert_redirected_to wallet_path(@wallet)
  end
end
