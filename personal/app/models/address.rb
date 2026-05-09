class Address < ApplicationRecord
  RECEIVE_BRANCH = 0
  CHANGE_BRANCH  = 1

  belongs_to :wallet

  validates :address, presence: true, uniqueness: true
  validates :branch, inclusion: { in: [RECEIVE_BRANCH, CHANGE_BRANCH] }
  validates :index_at_branch, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :receive,  -> { where(branch: RECEIVE_BRANCH) }
  scope :change,   -> { where(branch: CHANGE_BRANCH) }
  scope :ordered,  -> { order(:branch, :index_at_branch) }
  scope :used,     -> { where("tx_count > 0") }
  scope :unused,   -> { where(tx_count: 0) }

  def receive?
    branch == RECEIVE_BRANCH
  end

  def change?
    branch == CHANGE_BRANCH
  end

  def derivation_path
    "m/#{branch}/#{index_at_branch}"
  end

  def balance_btc
    balance_sats / 100_000_000.0
  end
end
