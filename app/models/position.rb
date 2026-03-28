class Position < ApplicationRecord
  belongs_to :user
  belongs_to :bot, optional: true
  has_many :trades

  enum :status, {
    open: "open",
    closed: "closed"
  }, prefix: true

  validates :exchange_name, :pair, :quantity, :average_price, :side, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :side, inclusion: { in: %w[long short] }

  scope :open_positions, -> { where(status: :open) }
  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :by_pair, ->(pair) { where(pair: pair) }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def long?
    side == "long"
  end

  def short?
    side == "short"
  end

  def update_pnl!(current_price:, total_fees:)
    return unless open?

    self.gross_pnl = gross_pnl_at(current_price)
    self.total_fees = total_fees
    self.net_pnl = gross_pnl - total_fees
    self.price = current_price
    save!
  end

  def close!(exit_price:, fees:)
    pnl = gross_pnl_at(exit_price)

    update!(
      status: :closed,
      gross_pnl: pnl,
      total_fees: fees,
      net_pnl: pnl - fees,
      quantity: 0
    )
  end

  private

  def gross_pnl_at(current_price)
    if long?
      (current_price - average_price) * quantity
    else
      (average_price - current_price) * quantity
    end
  end
end
