class Ticker < ApplicationRecord
  belongs_to :user, optional: true

  validates :exchange_name, :pair, :timestamp, presence: true
  validates :pair, uniqueness: { scope: [ :exchange_name ] }

  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :by_pair, ->(pair) { where(pair: pair) }
  scope :recent, -> { order(timestamp: :desc) }
  scope :stale, -> { where("updated_at < ?", 5.minutes.ago) }

  def self.upsert_from_value_object(exchange_name, value_object)
    find_or_initialize_by(
      exchange_name: exchange_name,
      pair: value_object.pair
    ).tap do |ticker|
      ticker.assign_attributes(
        bid: value_object.bid,
        ask: value_object.ask,
        last: value_object.last,
        volume_24h: value_object.volume_24h,
        price_change_24h: value_object.price_change_24h,
        price_change_percent_24h: value_object.price_change_percent_24h,
        high_24h: value_object.high_24h,
        low_24h: value_object.low_24h,
        timestamp: value_object.timestamp&.to_i || Time.now.to_i
      )
      ticker.save!
    end
  end

  def spread
    return nil if bid.nil? || ask.nil?
    ask - bid
  end

  def spread_percent
    return nil if spread.nil? || last.nil? || last.zero?
    (spread / last) * 100
  end
end
