class ExchangeCredential < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(is_active: true) }

  validates :exchange_name, presence: true
  validates :exchange_name, inclusion: { in: Exchanges::Registry.available }
  validates :api_key, presence: true, if: :requires_credentials?
  validates :api_secret, presence: true, if: :requires_credentials?

  encrypts :api_key, :api_secret

  def masked_api_key
    return nil if api_key.blank?
    return api_key if api_key.length <= 8
    "#{api_key[0..3]}...#{api_key[-4..-1]}"
  end

  def masked_api_secret
    return nil if api_secret.blank?
    "****"
  end

  def adapter
    return nil unless adapter_class

    accepted = adapter_class.instance_method(:initialize).parameters.map(&:last)

    credentials = {}
    credentials[:api_key] = api_key if api_key.present? && accepted.include?(:api_key)
    credentials[:api_secret] = api_secret if api_secret.present? && accepted.include?(:api_secret)
    credentials[:account_id] = account_id if account_id.present? && accepted.include?(:account_id)
    credentials[:environment] = environment&.to_sym if environment.present? && accepted.include?(:environment)

    adapter_class.new(**credentials)
  end

  def test_connection
    return false unless adapter

    adapter.test_connection
  rescue Exchanges::Error
    false
  end

  private

  def adapter_class
    "Exchanges::#{exchange_name.capitalize}".constantize
  rescue NameError
    nil
  end

  def requires_credentials?
    return false unless adapter_class

    adapter_class.required_credentials.any?
  end
end
