class WalletsController < ApplicationController
  before_action :set_wallet, only: [:show, :sync]

  def index
    @wallets = Wallet.order(created_at: :desc)
  end

  def show
    @receive_addresses = @wallet.addresses.receive.ordered
    @change_addresses  = @wallet.addresses.change.ordered
    @alert_events      = @wallet.alert_events.recent.limit(10)
    @utxos             = @wallet.utxos.includes(:address).by_value.limit(20)
  end

  def new
    @wallet = Wallet.new(network: "mainnet", gap_limit: 20)
  end

  def create
    @wallet = Wallet.new(wallet_params)
    if @wallet.save
      WalletSyncJob.perform_later(@wallet)
      flash[:notice] = "Wallet added — materializing & syncing in the background."
      redirect_to @wallet
    else
      render :new, status: :unprocessable_entity
    end
  end

  def sync
    WalletSyncJob.perform_later(@wallet)
    flash[:notice] = "Sync queued."
    redirect_to @wallet
  end

  private

  def set_wallet
    @wallet = Wallet.find(params[:id])
  end

  def wallet_params
    params.require(:wallet).permit(:name, :xpub, :network, :gap_limit, :ntfy_topic, :fee_threshold_sat_vb)
  end
end
