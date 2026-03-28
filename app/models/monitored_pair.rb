class MonitoredPair < ApplicationRecord
  belongs_to :user

  validates :exchange_name, :pair, presence: true
  validates :pair, uniqueness: { scope: [ :user_id, :exchange_name ] }
  validates :exchange_name, inclusion: { in: Exchanges::Registry.available }

  scope :active, -> { where(is_active: true) }
  scope :collecting_candles, -> { where(collect_candles: true) }
  scope :collecting_ticker, -> { where(collect_ticker: true) }
  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }

  def adapter
    return @adapter if defined?(@adapter)

    credential = user.exchange_credentials.find_by(exchange_name: exchange_name, is_active: true)
    return nil unless credential

    @adapter = credential.adapter
  end

  def fetch_and_store_candles
    return unless adapter && collect_candles && interval

    candles = adapter.fetch_candles(pair, interval, limit: 500)
    candles.each do |candle|
      Candle.upsert_from_value_object(exchange_name, candle)
    end
  end

  def fetch_and_store_ticker
    return unless adapter && collect_ticker

    ticker = adapter.fetch_ticker(pair)
    Ticker.upsert_from_value_object(exchange_name, ticker)
  end
end
