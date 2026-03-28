class Bot < ApplicationRecord
  belongs_to :user
  has_many :orders
  has_many :trades

  enum :mode, { auto: "auto", semi_auto: "semi_auto" }, prefix: true
  enum :status, { active: "active", paused: "paused", stopped: "stopped" }, prefix: true

  validates :exchange_name, :pair, :strategy, presence: true
  validates :ml_high_threshold, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_blank: true
  validates :ml_low_threshold, numericality: { greater_than_or_equal_to: 0, less_than: 1 }, allow_blank: true

  scope :active_bots, -> { where(status: :active) }
  scope :paused_bots, -> { where(status: :paused) }
  scope :by_exchange, ->(exchange) { where(exchange_name: exchange) }
  scope :ai_enabled, -> { where(ai_enabled: true) }

  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def stopped?
    status == "stopped"
  end

  def pause!
    update!(status: :paused)
  end

  def resume!
    update!(status: :active)
  end

  def stop!
    update!(status: :stopped)
  end

  def toggle_ai!
    update!(ai_enabled: !ai_enabled)
  end

  def strategy_class
    Strategy::Registry.get(strategy)
  end
end
