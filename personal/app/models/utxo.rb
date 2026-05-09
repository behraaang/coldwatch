class Utxo < ApplicationRecord
  belongs_to :address
  has_one :wallet, through: :address

  validates :txid, presence: true
  validates :vout, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :value_sats, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :txid, uniqueness: { scope: :vout }

  # A UTXO is "dust" if spending it costs more in fees than it's worth.
  # Rough heuristic: a P2WPKH input is ~68 vBytes. At 50 sat/vB, that's
  # 3,400 sats just to spend it. We flag anything < 5,000 sats as dust.
  DUST_THRESHOLD_SATS = 5_000

  scope :dust,    -> { where("value_sats < ?", DUST_THRESHOLD_SATS) }
  scope :nondust, -> { where("value_sats >= ?", DUST_THRESHOLD_SATS) }
  scope :confirmed,   -> { where(confirmed: true) }
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :by_value,    -> { order(value_sats: :desc) }

  def value_btc
    value_sats / 100_000_000.0
  end

  def dust?
    value_sats < DUST_THRESHOLD_SATS
  end

  def short_txid
    "#{txid[0, 6]}…#{txid[-4..]}"
  end

  def mempool_url
    "https://mempool.space/tx/#{txid}"
  end
end
