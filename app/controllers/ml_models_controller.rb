class MlModelsController < ApplicationController
  before_action :require_authentication
  before_action :set_ml_model, only: [ :show, :edit, :update, :destroy, :activate, :retire ]

  def index
    @ml_models = current_user.ml_models.order(created_at: :desc)
  end

  def show
  end

  def new
    @ml_model = current_user.ml_models.new
  end

  def create
    @ml_model = current_user.ml_models.new(ml_model_params)

    if @ml_model.save
      redirect_to @ml_model, notice: "ML model was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ml_model.update(ml_model_params)
      redirect_to @ml_model, notice: "ML model was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ml_model.destroy!
    redirect_to ml_models_url, notice: "ML model was successfully destroyed."
  end

  def train
    pair = params[:pair].presence || "BTC/USDT"
    days = (params[:days].presence || 90).to_i
    model_type = params[:model_type].presence || "lightgbm"
    features = params[:features].presence || "indicators"
    profit_pct = (params[:profit_pct].presence || 2.0).to_f
    loss_pct = (params[:loss_pct].presence || 1.0).to_f

    Ml::TrainModelJob.perform_later(
      user_id: current_user.id,
      pair: pair,
      days: days,
      model_type: model_type,
      features: features,
      profit_pct: profit_pct,
      loss_pct: loss_pct
    )

    redirect_to ml_models_path, notice: "Training started for #{pair} (#{days} days, #{model_type}). Progress will appear below."
  end

  def activate
    @ml_model.update!(status: :active)
    redirect_to ml_models_path, notice: "#{@ml_model.name} activated."
  end

  def retire
    @ml_model.update!(status: :retired)
    redirect_to ml_models_path, notice: "#{@ml_model.name} deactivated."
  end

  private

  def set_ml_model
    @ml_model = current_user.ml_models.find(params[:id])
  end

  def ml_model_params
    params.require(:ml_model).permit(:name, :version, :model_type, :status, :file_path, :training_date, :feature_list, :performance_metrics)
  end
end
