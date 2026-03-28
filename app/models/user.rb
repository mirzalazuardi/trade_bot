class User < ApplicationRecord
  MAX_FAILED_ATTEMPTS = 5
  LOCK_DURATION = 30.minutes

  has_secure_password
  has_many :sessions, dependent: :destroy

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

  private

  def lock!
    update!(locked_until: LOCK_DURATION.from_now)
  end
end
