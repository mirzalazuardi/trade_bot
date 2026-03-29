class Order < ApplicationRecord
  belongs_to :user
  belongs_to :bot, foreign_key: :bot_id
  belongs_to :trade, optional: true
  belongs_to :position, optional: true
  has_one :trade

  enum :status, {
    pending: "pending",
    submitted: "submitted",
    open: "open",
    partially_filled: "partially_filled",
    filled: "filled",
    cancelled: "cancelled",
    failed: "failed"
  }, prefix: true

  validates :quantity, :price, :exchange_name, :pair, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }

  scope :open_orders, -> { where(status: [ :open, :submitted, :partially_filled ]) }
  scope :filled_orders, -> { where(status: :filled) }
  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :by_pair, ->(pair) { where(pair: pair) }
  scope :recent, -> { order(created_at: :desc) }

  def filled?
    status == "filled"
  end

  def open?
    %w[open submitted partially_filled].include?(status)
  end

  def cancelled?
    status == "cancelled"
  end

  def failed?
    status == "failed"
  end
end
