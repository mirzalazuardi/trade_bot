class BacktestsController < ApplicationController
  before_action :require_authentication
  before_action :set_bot, only: [:create, :show]

  def create
    from_date = Date.parse(params[:from_date])
    to_date = Date.parse(params[:to_date])

    result = Trading::BacktestService.call(
      bot: @bot,
      from_date: from_date,
      to_date: to_date
    )

    if result[:error]
      redirect_to @bot, alert: result[:error]
    else
      @results = result
      render :show
    end
  end

  def show
    @bot = current_user.bots.find(params[:id])
  end

  private

  def set_bot
    @bot = current_user.bots.find(params[:bot_id] || params[:id])
  end
end
