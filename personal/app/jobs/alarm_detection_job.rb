# Async wrapper around OutgoingTxDetector. The MempoolSubscriber enqueues
# this on every address-activity event so the WebSocket reactor stays fast
# (the detector makes its own HTTPS calls + DB writes + ntfy push).
class AlarmDetectionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(address_id)
    address = Address.find_by(id: address_id)
    return unless address

    OutgoingTxDetector.process(address)
  end
end
