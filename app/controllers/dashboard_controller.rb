class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @total_pnl = current_user.trades.sum(:net_pnl)
    @total_fees = current_user.trades.sum(:total_fees)
    @active_bots = current_user.bots.where(status: :active).count
    @recent_trades = current_user.trades.recent.limit(5)
    @today_pnl = current_user.trades.where("closed_at > ?", Time.current.beginning_of_day).sum(:net_pnl)
    @today_trades = current_user.trades.where("closed_at > ?", Time.current.beginning_of_day).count

    @balances = fetch_balances
  end

  private

  def fetch_balances
    credentials = current_user.exchange_credentials.active.includes(:exchange_name)
    credentials.map do |cred|
      begin
        adapter = Exchanges::Registry.get(cred.exchange_name).new(cred)
        balance = adapter.fetch_balance
        { exchange: cred.exchange_name, balance: balance.available_balance, currency: balance.currency }
      rescue
        { exchange: cred.exchange_name, balance: "Error", currency: "" }
      end
    end
  end
end
