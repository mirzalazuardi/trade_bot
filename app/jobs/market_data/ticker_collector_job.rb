class MarketData::TickerCollectorJob < ApplicationJob
  queue_as :default

  discard_on Exchanges::RateLimitError

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(monitored_pair_id)
    monitored_pair = MonitoredPair.find_by(id: monitored_pair_id, is_active: true)
    return unless monitored_pair

    monitored_pair.fetch_and_store_ticker
  end
end
