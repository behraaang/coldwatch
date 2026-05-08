class WalletsController < ApplicationController
  before_action :set_wallet, only: [:show]

  def index
    @wallets = Wallet.order(created_at: :desc)
  end

  def show
    deriver = XpubDerivation.new(xpub: @wallet.xpub, network: @wallet.network)
    @receive_addresses = deriver.receive_addresses(count: 5)
    @change_addresses  = deriver.change_addresses(count: 5)
  rescue StandardError => e
    @derivation_error = e.message
  end

  def new
    @wallet = Wallet.new(network: "mainnet", gap_limit: 20)
  end

  def create
    @wallet = Wallet.new(wallet_params)
    if @wallet.save
      redirect_to @wallet, notice: "Wallet added — derivation working below."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_wallet
    @wallet = Wallet.find(params[:id])
  end

  def wallet_params
    params.require(:wallet).permit(:name, :xpub, :network, :gap_limit)
  end
end
