class ExchangeCredentialsController < ApplicationController
  before_action :require_authentication
  before_action :set_credential, only: %i[show edit update destroy test_connection]

  def index
    @credentials = current_user.exchange_credentials.order(created_at: :desc)
  end

  def show
  end

  def new
    @credential = current_user.exchange_credentials.build
    @exchanges = Exchanges::Registry.available.map do |name|
      [ name.titleize, name ]
    end
  end

  def create
    @credential = current_user.exchange_credentials.build(credential_params)

    if @credential.save
      redirect_to exchange_credentials_path, notice: "Credential created successfully."
    else
      @exchanges = Exchanges::Registry.available.map { |name| [ name.titleize, name ] }
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @exchanges = Exchanges::Registry.available.map { |name| [ name.titleize, name ] }
  end

  def update
    if @credential.update(credential_params)
      redirect_to exchange_credentials_path, notice: "Credential updated successfully."
    else
      @exchanges = Exchanges::Registry.available.map { |name| [ name.titleize, name ] }
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @credential.destroy
    redirect_to exchange_credentials_path, notice: "Credential deleted."
  end

  def test_connection
    result = @credential.test_connection

    if result
      redirect_to exchange_credentials_path, notice: "Connection successful!"
    else
      redirect_to exchange_credentials_path, alert: "Connection failed. Please check your credentials."
    end
  end

  private

  def set_credential
    @credential = current_user.exchange_credentials.find(params[:id])
  end

  def credential_params
    params.require(:exchange_credential).permit(
      :exchange_name,
      :api_key,
      :api_secret,
      :account_id,
      :environment,
      :is_active
    )
  end
end
