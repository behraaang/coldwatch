class Wallet < ApplicationRecord
  encrypts :xpub

  XPUB_PREFIXES = {
    "mainnet" => %w[zpub].freeze,
    "testnet" => %w[vpub Vpub].freeze
  }.freeze

  has_many :addresses, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :xpub, presence: true
  validates :network, inclusion: { in: %w[mainnet testnet] }
  validates :gap_limit,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validate :xpub_prefix_must_match_network

  def balance_sats
    addresses.sum(:balance_sats)
  end

  def balance_btc
    balance_sats / 100_000_000.0
  end

  def total_tx_count
    addresses.sum(:tx_count)
  end

  def last_synced_at
    addresses.maximum(:last_synced_at)
  end

  def synced?
    last_synced_at.present?
  end

  private

  def xpub_prefix_must_match_network
    return if xpub.blank? || network.blank?

    valid_prefixes = XPUB_PREFIXES.fetch(network, [])
    return if valid_prefixes.any? { |p| xpub.start_with?(p) }

    errors.add(
      :xpub,
      "must start with #{valid_prefixes.join(' or ')} for #{network} (BIP84 Native SegWit only in v1)"
    )
  end
end
