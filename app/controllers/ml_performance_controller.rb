class MlPerformanceController < ApplicationController
  before_action :require_authentication

  def index
    @ml_models = current_user.ml_models.order(created_at: :desc)
    @bots = current_user.bots.order(created_at: :desc)

    ml_model_id = params[:ml_model_id]
    bot_id = params[:bot_id]
    from_date = params[:from]&.to_date
    to_date = params[:to]&.to_date

    @performance = MlAnalytics::Performance.call(
      user: current_user,
      bot_id: bot_id.presence&.to_i,
      ml_model_id: ml_model_id.presence&.to_i,
      from_date: from_date,
      to_date: to_date
    )
  end
end
