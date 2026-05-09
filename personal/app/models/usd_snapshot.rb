# Daily USD-per-BTC snapshot. Powers the BTC→USD display on wallet pages
# and (later) the balance-over-time chart. UsdSnapshotJob upserts one row
# per UTC date.
class UsdSnapshot < ApplicationRecord
  validates :captured_on, presence: true, uniqueness: true
  validates :price_usd, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { order(captured_on: :desc) }

  def self.latest
    order(captured_on: :desc).first
  end

  def self.latest_price
    latest&.price_usd
  end
end
