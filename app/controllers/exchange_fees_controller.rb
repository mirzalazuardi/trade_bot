class ExchangeFeesController < ApplicationController
  before_action :authenticate_user!

  def index
    @exchange_fees = ExchangeFee.all.order(:exchange_name)
  end

  def edit
    @exchange_fee = ExchangeFee.find(params[:id])
  end

  def update
    @exchange_fee = ExchangeFee.find(params[:id])

    if @exchange_fee.update(exchange_fee_params)
      redirect_to exchange_fees_url, notice: "Fee schedule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def sync
    @exchange_fee = ExchangeFee.find(params[:id])
    exchange_name = @exchange_fee.exchange_name

    begin
      credential = current_user.exchange_credentials.active.find_by(exchange_name: exchange_name)
      adapter = Exchanges::Registry.get(exchange_name).new(credential)
      fee_schedule = adapter.fetch_fee_schedule

      @exchange_fee.update!(
        maker_rate: fee_schedule.maker_rate,
        taker_rate: fee_schedule.taker_rate,
        typical_spreads: fee_schedule.typical_spreads
      )

      redirect_to exchange_fees_url, notice: "Fee schedule synced from API."
    rescue => e
      redirect_to exchange_fees_url, alert: "Sync failed: #{e.message}"
    end
  end

  private

  def exchange_fee_params
    params.require(:exchange_fee).permit(:maker_rate, :taker_rate, :spread_based, :typical_spreads)
  end
end
