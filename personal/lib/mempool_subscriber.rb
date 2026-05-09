require "faye/websocket"
require "eventmachine"
require "json"
require "set"

# Long-lived WebSocket subscriber to mempool.space.
#
# Runs as its own container (`mempool_subscriber` service in docker-compose).
# Holds one WS per network for which we have wallets, subscribes to every
# address we're watching, and on each address activity event:
#   1. Re-fetches authoritative state from mempool.space REST (cheap, 1 call)
#   2. Updates the Address row (balance_sats, tx_count, last_synced_at)
#   3. Broadcasts Turbo Stream replacements of the wallet's balance card
#      and addresses panel — so any browser open on the wallet's show page
#      sees live updates with no manual refresh.
#
# Day 4b. The alarm-on-outgoing-tx logic and the ntfy push come in Day 5.
class MempoolSubscriber
  WS_URLS = {
    "mainnet" => "wss://mempool.space/api/v1/ws",
    "testnet" => "wss://mempool.space/testnet/api/v1/ws"
  }.freeze

  REFRESH_INTERVAL_SECONDS = 30
  RECONNECT_INITIAL_BACKOFF_SECONDS = 5
  RECONNECT_MAX_BACKOFF_SECONDS = 300

  def self.run
    Rails.logger.info("[MempoolSubscriber] starting; pid=#{Process.pid}")
    backoff = RECONNECT_INITIAL_BACKOFF_SECONDS

    loop do
      begin
        run_once
        backoff = RECONNECT_INITIAL_BACKOFF_SECONDS  # clean disconnect resets
      rescue StandardError => e
        Rails.logger.error("[MempoolSubscriber] crashed: #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n"))
      end

      Rails.logger.warn("[MempoolSubscriber] reconnecting in #{backoff}s")
      sleep(backoff)
      backoff = [backoff * 2, RECONNECT_MAX_BACKOFF_SECONDS].min
    end
  end

  # One EM reactor iteration: open WS per network, subscribe, hold open.
  # EM.stop is called on close; this method returns and the outer loop
  # decides whether to reconnect.
  def self.run_once
    # Long-running scripts get bitten by AR query cache + Postgres transaction
    # isolation: a connection checked out at boot may keep returning empty
    # results even after another process commits. Force a clean checkout.
    ActiveRecord::Base.connection_handler.clear_active_connections!

    addresses_by_network = group_addresses_by_network
    if addresses_by_network.empty?
      Rails.logger.info("[MempoolSubscriber] no addresses to watch; sleeping #{REFRESH_INTERVAL_SECONDS}s")
      sleep(REFRESH_INTERVAL_SECONDS)
      return
    end

    EM.run do
      addresses_by_network.each do |network, address_strings|
        connect_for_network(network, address_strings)
      end

      # Periodically refresh subscriptions so new wallets/addresses get tracked
      # without a restart. Re-sending track-addresses with the full list
      # replaces the prior subscription on mempool.space's side.
      EM.add_periodic_timer(REFRESH_INTERVAL_SECONDS) do
        @sockets.each do |network, ws|
          current = Address.joins(:wallet).where(wallets: { network: network }).pluck(:address)
          if current.any?
            ws.send({ "track-addresses": current }.to_json)
            Rails.logger.debug("[MempoolSubscriber] refreshed #{network} → #{current.size} addresses")
          end
        end
      end
    end
  end

  def self.group_addresses_by_network
    Address.joins(:wallet).group("wallets.network").pluck("wallets.network", "array_agg(addresses.address)").to_h
  rescue StandardError
    # SQLite (test env) doesn't have array_agg; fall back per-network
    Wallet.distinct.pluck(:network).each_with_object({}) do |net, acc|
      addrs = Address.joins(:wallet).where(wallets: { network: net }).pluck(:address)
      acc[net] = addrs if addrs.any?
    end
  end

  @sockets = {}

  def self.connect_for_network(network, address_strings)
    url = WS_URLS.fetch(network) do
      Rails.logger.warn("[MempoolSubscriber] unknown network #{network}, skipping")
      return
    end

    ws = Faye::WebSocket::Client.new(url)

    ws.on :open do
      Rails.logger.info("[MempoolSubscriber] connected #{network} #{url}")
      ws.send({ action: "want", data: ["blocks"] }.to_json)
      ws.send({ "track-addresses": address_strings }.to_json)
      Rails.logger.info("[MempoolSubscriber] subscribed #{network} → #{address_strings.size} addresses")
    end

    ws.on :message do |event|
      handle_message(network, event.data)
    rescue StandardError => e
      Rails.logger.error("[MempoolSubscriber] message error: #{e.class}: #{e.message}")
    end

    ws.on :close do |event|
      Rails.logger.warn("[MempoolSubscriber] #{network} closed code=#{event.code} reason=#{event.reason}")
      @sockets.delete(network)
      EM.stop if @sockets.empty?
    end

    ws.on :error do |event|
      Rails.logger.error("[MempoolSubscriber] #{network} error: #{event.message}")
    end

    @sockets[network] = ws
  end

  def self.handle_message(network, raw)
    data = JSON.parse(raw)

    if data["address-transactions"].is_a?(Hash)
      data["address-transactions"].each do |addr_str, _txs|
        on_address_activity(addr_str, network: network)
      end
    elsif data["block"].is_a?(Hash)
      Rails.logger.info("[MempoolSubscriber] block height=#{data['block']['height']}")
    end
  end

  def self.on_address_activity(addr_str, network:)
    addr = Address.find_by(address: addr_str)
    return unless addr

    Rails.logger.info("[MempoolSubscriber] activity on #{addr_str} (#{network}); refetching")

    base = MempoolFetcher::BASE_URLS.fetch(network)
    fresh = MempoolFetcher.fetch(addr_str, base: base)
    return unless fresh

    addr.update!(
      balance_sats: fresh[:balance_sats],
      tx_count: fresh[:tx_count],
      last_synced_at: Time.current
    )

    broadcast_wallet_update(addr.wallet)
  end

  def self.broadcast_wallet_update(wallet)
    Turbo::StreamsChannel.broadcast_replace_to(
      wallet,
      target: ActionView::RecordIdentifier.dom_id(wallet, :balance_card),
      partial: "wallets/balance_card",
      locals: { wallet: wallet }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      wallet,
      target: ActionView::RecordIdentifier.dom_id(wallet, :addresses_panel),
      partial: "wallets/addresses_panel",
      locals: {
        wallet: wallet,
        receive_addresses: wallet.addresses.receive.ordered,
        change_addresses:  wallet.addresses.change.ordered
      }
    )
  end
end
