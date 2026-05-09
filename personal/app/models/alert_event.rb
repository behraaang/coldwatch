class AlertEvent < ApplicationRecord
  DIRECTIONS = %w[outgoing incoming].freeze

  belongs_to :wallet

  validates :txid, presence: true, uniqueness: { scope: :wallet_id }
  validates :direction, inclusion: { in: DIRECTIONS }

  scope :outgoing, -> { where(direction: "outgoing") }
  scope :incoming, -> { where(direction: "incoming") }
  scope :recent,   -> { order(created_at: :desc) }
  scope :dispatched, -> { where.not(dispatched_at: nil) }

  def amount_btc
    return nil if amount_sats.nil?
    amount_sats / 100_000_000.0
  end

  def short_txid
    "#{txid[0, 8]}…#{txid[-6..]}"
  end

  def mempool_url
    "https://mempool.space/tx/#{txid}"
  end
end
