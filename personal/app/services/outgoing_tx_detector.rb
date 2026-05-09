require "set"

# Classifies recent transactions on an address as outgoing/incoming/unrelated,
# records an AlertEvent for any new outgoing tx, and dispatches the ntfy push.
#
# Idempotent — if the (wallet, txid) pair already exists, it's skipped.
# Confirmation status is recorded but does not gate the alarm; we want
# 0-conf alarms because the entire point is to fire BEFORE confirmation
# so the user has an RBF window.
class OutgoingTxDetector
  # Scan recent txs touching `address_record.address`, alarm on new outgoing.
  def self.process(address_record)
    base = MempoolFetcher::BASE_URLS.fetch(address_record.wallet.network)
    txs = MempoolFetcher.fetch_txs(address_record.address, base: base) || []
    return [] if txs.empty?

    wallet = address_record.wallet
    our_addresses = wallet.addresses.pluck(:address).to_set
    fired = []

    txs.each do |tx|
      txid = tx["txid"]
      next if txid.blank?
      next if AlertEvent.exists?(wallet: wallet, txid: txid)

      direction = classify(tx, our_addresses)
      next unless direction == "outgoing"

      amount = outgoing_amount_sats(tx, our_addresses)
      status = tx["status"] || {}
      event = AlertEvent.create!(
        wallet:       wallet,
        txid:         txid,
        direction:    direction,
        amount_sats:  amount,
        confirmed:    !!status["confirmed"],
        block_height: status["block_height"]
      )

      NtfyPusher.dispatch(event) if wallet.ntfy_topic.present?
      fired << event
    end

    fired
  end

  # Pure function — directly testable. Returns "outgoing" / "incoming" /
  # "unrelated" given a mempool.space tx hash and our address set.
  def self.classify(tx, our_addresses)
    return "outgoing" if any_input_ours?(tx, our_addresses)
    return "incoming" if any_output_ours?(tx, our_addresses)

    "unrelated"
  end

  # Net sats moved out of the wallet:
  #   sum(inputs spent from our addresses) - sum(outputs back to our addresses)
  def self.outgoing_amount_sats(tx, our_addresses)
    spent = (tx["vin"] || []).sum do |vin|
      addr = vin.dig("prevout", "scriptpubkey_address")
      our_addresses.include?(addr) ? vin.dig("prevout", "value").to_i : 0
    end
    returned = (tx["vout"] || []).sum do |vout|
      addr = vout["scriptpubkey_address"]
      our_addresses.include?(addr) ? vout["value"].to_i : 0
    end
    spent - returned
  end

  def self.any_input_ours?(tx, our_addresses)
    (tx["vin"] || []).any? do |vin|
      our_addresses.include?(vin.dig("prevout", "scriptpubkey_address"))
    end
  end

  def self.any_output_ours?(tx, our_addresses)
    (tx["vout"] || []).any? do |vout|
      our_addresses.include?(vout["scriptpubkey_address"])
    end
  end
end
