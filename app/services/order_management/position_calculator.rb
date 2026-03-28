module OrderManagement
  class PositionCalculator
    def self.call(user:, exchange_name:, pair:)
      new(user: user, exchange_name: exchange_name, pair: pair).calculate
    end

    def initialize(user:, exchange_name:, pair:)
      @user = user
      @exchange_name = exchange_name
      @pair = pair
    end

    def calculate
      closed_trades = Trade.where(user: @user, exchange_name: @exchange_name, pair: @pair).where.not(closed_at: nil)
      closed_pnl = closed_trades.sum(:net_pnl)
      closed_fees = closed_trades.sum(:total_fees)

      open_buy = Order.filled_orders.where(user: @user, exchange_name: @exchange_name, pair: @pair, side: :buy).order(created_at: :desc).first
      open_sell = Order.filled_orders.where(user: @user, exchange_name: @exchange_name, pair: @pair, side: :sell).order(created_at: :desc).first

      {
        total_pnl: closed_pnl,
        total_fees: closed_fees,
        trade_count: closed_trades.count,
        open_positions: open_buy.present? ? 1 : 0
      }
    end
  end
end
