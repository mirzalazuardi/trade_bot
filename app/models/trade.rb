class Trade < ApplicationRecord
  belongs_to :user
  belongs_to :bot, foreign_key: :bot_id
  belongs_to :order, foreign_key: :order_id

  validates :exchange_name, :pair, :quantity, :entry_price, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :entry_price, numericality: { greater_than: 0 }

  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :by_pair, ->(pair) { where(pair: pair) }
  scope :recent, -> { order(closed_at: :desc) }
  scope :winners, -> { where("net_pnl > 0") }
  scope :losers, -> { where("net_pnl < 0") }
  scope :by_date_range, ->(from, to) { where(closed_at: from..to) }

  after_update :update_ml_outcomes

  def closed?
    closed_at.present?
  end

  def open?
    !closed?
  end

  def roi
    return 0 if entry_price.zero? || exit_price.nil?

    pnl_per_unit = if side == "sell"
      entry_price - exit_price
    else
      exit_price - entry_price
    end

    (pnl_per_unit / entry_price * 100).round(2)
  end

  private

  def update_ml_outcomes
    return unless closed? && saved_change_to_closed_at?
    MarketData::UpdateMlOutcomesJob.update_for_trade(self)
  end
end
