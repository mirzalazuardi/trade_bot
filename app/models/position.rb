class Position < ApplicationRecord
  belongs_to :user
  has_many :trades

  enum :status, {
    open: "open",
    closed: "closed"
  }, prefix: true

  validates :exchange_name, :pair, :quantity, :average_price, presence: true
  validates :quantity, numericality: { greater_than: 0 }

  scope :open_positions, -> { where(status: :open) }
  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :by_pair, ->(pair) { where(pair: pair) }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def update_pnl!(current_price:, total_fees:)
    return unless open?

    self.gross_pnl = (current_price - average_price) * quantity
    self.total_fees = total_fees
    self.net_pnl = gross_pnl - total_fees
    self.price = current_price
    save!
  end

  def close!(exit_price:, fees:)
    update!(
      status: :closed,
      gross_pnl: (exit_price - average_price) * quantity,
      total_fees: fees,
      net_pnl: (exit_price - average_price) * quantity - fees,
      quantity: 0
    )
  end
end
