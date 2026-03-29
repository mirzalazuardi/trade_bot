class StrategiesController < ApplicationController
  before_action :require_authentication

  def index
    @strategies = current_user.custom_strategies.order(created_at: :desc)
    @built_in = Strategy::Registry.available
  end

  def show
    @strategy = current_user.custom_strategies.find(params[:id])
    render json: @strategy.config
  end

  def create
    if params[:file].present?
      json_string = params[:file].read
      @strategy = CustomStrategy.from_json(json_string, user: current_user)
    else
      @strategy = current_user.custom_strategies.new(strategy_params)
    end

    if @strategy.save
      redirect_to strategies_path, notice: "Strategy created successfully"
    else
      @strategies = current_user.custom_strategies.order(created_at: :desc)
      render :index, alert: @strategy.errors.full_messages.join(", ")
    end
  end

  def update
    @strategy = current_user.custom_strategies.find(params[:id])

    if @strategy.update(strategy_params)
      redirect_to strategies_path, notice: "Strategy updated"
    else
      redirect_to strategies_path, alert: @strategy.errors.full_messages.join(", ")
    end
  end

  def destroy
    @strategy = current_user.custom_strategies.find(params[:id])
    @strategy.destroy
    redirect_to strategies_path, notice: "Strategy deleted"
  end

  def export
    @strategy = current_user.custom_strategies.find(params[:id])
    send_data @strategy.to_json, filename: "#{@strategy.name.underscore}.json", content_type: "application/json"
  end

  private

  def strategy_params
    params.require(:custom_strategy).permit(:name, :config)
  end
end
