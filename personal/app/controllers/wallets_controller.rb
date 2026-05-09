class WalletsController < ApplicationController
  before_action :set_wallet, only: [:show, :sync]

  def index
    @wallets = Wallet.order(created_at: :desc)
  end

  def show
    @receive_addresses = @wallet.addresses.receive.ordered
    @change_addresses  = @wallet.addresses.change.ordered
  end

  def new
    @wallet = Wallet.new(network: "mainnet", gap_limit: 20)
  end

  def create
    @wallet = Wallet.new(wallet_params)
    if @wallet.save
      AddressDerivation.materialize_all(@wallet)
      result = MempoolFetcher.sync_wallet(@wallet)
      flash[:notice] = "Wallet added · synced #{result[:synced]} addresses · " \
                       "#{format_btc(@wallet.balance_btc)} BTC"
      redirect_to @wallet
    else
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("[WalletsController#create] #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    @wallet&.destroy
    @wallet = Wallet.new(wallet_params)
    @wallet.errors.add(:base, "Sync failed: #{e.message}")
    render :new, status: :unprocessable_entity
  end

  def sync
    result = MempoolFetcher.sync_wallet(@wallet)
    if result[:failed].any?
      flash[:alert] = "Synced #{result[:synced]} addresses · #{result[:failed].size} failed"
    else
      flash[:notice] = "Synced #{result[:synced]} addresses"
    end
    redirect_to @wallet
  end

  private

  def set_wallet
    @wallet = Wallet.find(params[:id])
  end

  def wallet_params
    params.require(:wallet).permit(:name, :xpub, :network, :gap_limit)
  end

  def format_btc(btc)
    format("%.8f", btc).sub(/\.?0+$/, "")
  end
end
