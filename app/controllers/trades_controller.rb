class TradesController < ApplicationController
  before_action :require_authentication

  def index
    @trades = current_user.trades.recent
    @trades = @trades.by_exchange(params[:exchange]) if params[:exchange].present?
    @trades = @trades.by_pair(params[:pair]) if params[:pair].present?
    @trades = @trades.where(side: params[:side]) if params[:side].present?

    if params[:from_date].present? && params[:to_date].present?
      @trades = @trades.by_date_range(Date.parse(params[:from_date]), Date.parse(params[:to_date]))
    end

    @total_pnl = @trades.sum(:net_pnl)
    @total_fees = @trades.sum(:total_fees)
  end
end
