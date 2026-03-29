class CustomStrategy < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :config, presence: true

  def analyze(candles, indicators:)
    Trading::Strategies::JsonExecutor.call(
      config: config,
      candles: candles,
      indicators: indicators
    )
  end

  def required_indicators
    (config["indicators"] || {}).keys.map(&:to_sym)
  end

  def self.from_json(json_string, user:)
    parsed = JSON.parse(json_string)
    create!(
      name: parsed["name"],
      config: parsed,
      user: user
    )
  end

  def to_json
    config.to_json
  end
end
