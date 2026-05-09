class Wallet < ApplicationRecord
  encrypts :xpub
  encrypts :ntfy_topic

  XPUB_PREFIXES = {
    "mainnet" => %w[zpub].freeze,
    "testnet" => %w[vpub Vpub].freeze
  }.freeze

  NTFY_TOPIC_FORMAT = /\A[A-Za-z0-9_\-]{8,64}\z/.freeze

  has_many :addresses, dependent: :destroy
  has_many :alert_events, dependent: :destroy
  has_many :utxos, through: :addresses

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :xpub, presence: true
  validates :network, inclusion: { in: %w[mainnet testnet] }
  validates :gap_limit,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :ntfy_topic, format: { with: NTFY_TOPIC_FORMAT }, allow_blank: true
  validates :fee_threshold_sat_vb,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 1000 },
            allow_nil: true
  validate :xpub_prefix_must_match_network

  def utxo_count
    utxos.count
  end

  def balance_usd
    price = UsdSnapshot.latest_price
    return nil if price.nil?
    (balance_btc * price.to_f).round(2)
  end

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
