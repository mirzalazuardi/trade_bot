class User < ApplicationRecord
  MAX_FAILED_ATTEMPTS = 5
  LOCK_DURATION = 30.minutes

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :exchange_credentials, dependent: :destroy
  has_many :bots, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :trades, dependent: :destroy
  has_many :ml_models, dependent: :destroy
  has_many :ml_prediction_logs, dependent: :destroy
  has_many :approvals, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def locked?
    locked_until.present? && locked_until > Time.current
  end

  def register_failed_login!
    increment!(:failed_attempts)
    lock! if failed_attempts >= MAX_FAILED_ATTEMPTS
  end

  def reset_failed_login!
    update!(failed_attempts: 0, locked_until: nil)
  end

  def telegram_enabled?
    telegram_enabled == true && telegram_chat_id.present?
  end

  private

  def lock!
    update!(locked_until: LOCK_DURATION.from_now)
  end
end
