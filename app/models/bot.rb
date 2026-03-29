class Bot < ApplicationRecord
  belongs_to :user
  belongs_to :custom_strategy, optional: true
  has_many :orders
  has_many :trades
  has_many :positions

  enum :mode, { auto: "auto", semi_auto: "semi_auto", paper_trade: "paper_trade", backtest: "backtest" }, prefix: true
  enum :status, { active: "active", paused: "paused", stopped: "stopped" }, prefix: true

  validates :exchange_name, :pair, presence: true
  validates :strategy, presence: true, unless: :custom_strategy_id?
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
    if custom_strategy_id?
      nil
    else
      Strategy::Registry.get(strategy)
    end
  end

  def custom_strategy?
    custom_strategy_id.present?
  end

  def strategy_name
    custom_strategy? ? custom_strategy.name : strategy.titleize
  end

  def analyze_candles(candles, indicators:)
    if custom_strategy?
      custom_strategy.analyze(candles, indicators: indicators)
    else
      strategy_class.new.analyze(candles, indicators: indicators)
    end
  end

  def required_indicators
    if custom_strategy?
      custom_strategy.required_indicators
    else
      strategy_class.required_indicators
    end
  end

  def risk_config
    OpenStruct.new(
      max_position_percent: max_position_pct || 10,
      max_daily_loss_percent: max_daily_loss_pct || 2,
      max_open_orders: max_open_orders || 10
    )
  end

  def portfolio_value
    positions.open_positions.sum { |p| p.quantity * p.current_price }
  end

  def daily_pnl
    trades.where("closed_at > ?", Time.current.beginning_of_day).sum(:net_pnl)
  end

  def open_orders_count
    orders.where(status: "open").count
  end
end
