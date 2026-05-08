# Derives BIP84 (Native SegWit P2WPKH) addresses from an extended public key.
# Receive branch  : m/<account>/0/i  → bc1q... (mainnet) or tb1q... (testnet)
# Change branch   : m/<account>/1/i
#
# NOTE on bitcoinrb's chain_params: it's a process-global. We set it on every
# derive() call. Single-threaded controller use is fine. When we add Sidekiq
# workers that derive across multiple networks concurrently (Week 1 Day 4),
# we'll wrap derivation in a Mutex or move to a per-call API.
class XpubDerivation
  RECEIVE_BRANCH = 0
  CHANGE_BRANCH  = 1

  def initialize(xpub:, network: "mainnet")
    @network = network.to_s
    @xpub = xpub
  end

  def receive_addresses(count: 5)
    derive(RECEIVE_BRANCH, count)
  end

  def change_addresses(count: 5)
    derive(CHANGE_BRANCH, count)
  end

  private

  def derive(branch, count)
    Bitcoin.chain_params = @network.to_sym
    ext = Bitcoin::ExtPubkey.from_base58(@xpub)
    branch_key = ext.derive(branch)
    Array.new(count) do |i|
      child = branch_key.derive(i)
      { path: "m/#{branch}/#{i}", address: child.addr }
    end
  end
end
