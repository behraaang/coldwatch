# Syncs the UTXO set for a single Address from mempool.space's
# /api/address/{addr}/utxo endpoint.
#
# Idempotent. Existing UTXOs are upserted. Orphan UTXOs (in our DB but
# absent from the response) are deleted — they were spent.
class UtxoSyncer
  def self.sync_address(address)
    base = MempoolFetcher::BASE_URLS.fetch(address.wallet.network)
    fresh = MempoolFetcher.fetch_utxos(address.address, base: base)
    return if fresh.nil?

    seen_pairs = []

    fresh.each do |u|
      txid = u["txid"]
      vout = u["vout"].to_i
      next if txid.blank?

      status = u["status"] || {}
      utxo = Utxo.find_or_initialize_by(txid: txid, vout: vout)
      utxo.address      = address
      utxo.value_sats   = u["value"].to_i
      utxo.confirmed    = !!status["confirmed"]
      utxo.block_height = status["block_height"]
      utxo.fetched_at   = Time.current
      utxo.save!

      seen_pairs << [txid, vout]
    end

    # Drop any UTXOs we previously persisted for this address that are no
    # longer in the response (they got spent).
    address.utxos.find_each do |existing|
      existing.destroy unless seen_pairs.include?([existing.txid, existing.vout])
    end
  end
end
