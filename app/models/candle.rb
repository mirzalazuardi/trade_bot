class Candle < ApplicationRecord
  belongs_to :user, optional: true

  validates :exchange_name, :pair, :interval, :timestamp, presence: true
  validates :timestamp, uniqueness: { scope: [ :exchange_name, :pair, :interval ] }

  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :by_pair, ->(pair) { where(pair: pair) }
  scope :by_interval, ->(interval) { where(interval: interval) }
  scope :recent, -> { order(timestamp: :desc) }
  scope :closed, -> { where(closed: true) }

  def self.upsert_from_value_object(exchange_name, value_object)
    find_or_initialize_by(
      exchange_name: exchange_name,
      pair: value_object.pair,
      interval: value_object.interval,
      timestamp: value_object.timestamp.to_i
    ).tap do |candle|
      candle.assign_attributes(
        open: value_object.open,
        high: value_object.high,
        low: value_object.low,
        close: value_object.close,
        volume: value_object.volume,
        closed: value_object.closed
      )
      candle.save!
    end
  end
end
