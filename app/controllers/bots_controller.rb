class BotsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bot, only: [ :show, :edit, :update, :destroy, :pause, :resume, :stop, :toggle_ai ]

  def index
    @bots = current_user.bots.order(created_at: :desc)
  end

  def show
  end

  def new
    @bot = current_user.bots.new
    @strategies = Strategy::Registry.available
    @exchanges = Exchanges::Registry.available
    @ml_models = current_user.ml_models.active_models if current_user.ml_models.any?
  end

  def create
    @bot = current_user.bots.new(bot_params)

    if @bot.save
      redirect_to @bot, notice: "Bot was successfully created."
    else
      @strategies = Strategy::Registry.available
      @exchanges = Exchanges::Registry.available
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @strategies = Strategy::Registry.available
    @exchanges = Exchanges::Registry.available
    @ml_models = current_user.ml_models.active_models if current_user.ml_models.any?
  end

  def update
    if @bot.update(bot_params)
      redirect_to @bot, notice: "Bot was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bot.destroy!
    redirect_to bots_url, notice: "Bot was successfully destroyed."
  end

  def pause
    @bot.pause!
    redirect_to @bot, notice: "Bot paused."
  end

  def resume
    @bot.resume!
    redirect_to @bot, notice: "Bot resumed."
  end

  def stop
    @bot.stop!
    redirect_to @bot, notice: "Bot stopped."
  end

  def toggle_ai
    @bot.toggle_ai!
    redirect_to @bot, notice: "AI #{@bot.ai_enabled ? 'enabled' : 'disabled'}."
  end

  private

  def set_bot
    @bot = current_user.bots.find(params[:id])
  end

  def bot_params
    params.require(:bot).permit(:exchange_name, :pair, :strategy, :mode, :ai_enabled, :ml_model_id, :ml_high_threshold, :ml_low_threshold)
  end
end
