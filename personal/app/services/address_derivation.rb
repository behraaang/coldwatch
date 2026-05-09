# Derives BIP84 (Native SegWit P2WPKH) addresses from a wallet's xpub
# AND persists them to the wallet's `addresses` association.
#
# Replaces the earlier XpubDerivation pure-function service. Kept the same
# public shape (RECEIVE_BRANCH / CHANGE_BRANCH constants) for callers that
# still want raw derivation without persistence.
#
# NOTE on bitcoinrb's chain_params: it's a process-global. Single-threaded
# controller use is fine. When Sidekiq workers derive concurrently across
# multiple networks (Day 4+), wrap calls in a Mutex.
class AddressDerivation
  RECEIVE_BRANCH = Address::RECEIVE_BRANCH
  CHANGE_BRANCH  = Address::CHANGE_BRANCH

  # Persists all addresses for a wallet up to its gap_limit on both branches.
  # Idempotent: re-running won't duplicate addresses (uses find_or_create_by!).
  def self.materialize_all(wallet)
    Bitcoin.chain_params = wallet.network.to_sym
    ext = Bitcoin::ExtPubkey.from_base58(wallet.xpub)

    [RECEIVE_BRANCH, CHANGE_BRANCH].each do |branch|
      branch_key = ext.derive(branch)
      wallet.gap_limit.times do |i|
        addr = branch_key.derive(i).addr
        wallet.addresses.find_or_create_by!(branch: branch, index_at_branch: i) do |a|
          a.address = addr
        end
      end
    end
  end

  # Pure-function derivation — used by tests / one-off lookups.
  def self.derive_one(xpub:, network:, branch:, index:)
    Bitcoin.chain_params = network.to_sym
    ext = Bitcoin::ExtPubkey.from_base58(xpub)
    ext.derive(branch).derive(index).addr
  end
end
