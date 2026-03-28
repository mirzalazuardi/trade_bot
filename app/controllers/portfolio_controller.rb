class PortfolioController < ApplicationController
  before_action :authenticate_user!

  def show
    @positions = current_user.positions.open_positions.group_by(&:exchange_name)

    @trades_by_exchange = current_user.trades.group(:exchange_name).sum(:net_pnl)
    @fees_by_exchange = current_user.trades.group(:exchange_name).sum(:total_fees)

    @credentials = current_user.exchange_credentials.active
  end
end
