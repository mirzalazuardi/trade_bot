class MlPredictionLog < ApplicationRecord
  belongs_to :user
  belongs_to :bot, foreign_key: :bot_id
  belongs_to :ml_model

  validates :confidence, :signal_type, presence: true

  scope :by_bot, ->(bot_id) { where(bot_id: bot_id) }
  scope :by_model, ->(model_id) { where(ml_model_id: model_id) }
  scope :executed, -> { where(trade_executed: true) }
  scope :profitable, -> { where(trade_profitable: true) }

  def self.log_prediction(bot:, model:, confidence:, signal_type:, features:, trade_executed: false)
    create!(
      user: bot.user,
      bot: bot,
      ml_model: model,
      confidence: confidence,
      signal_type: signal_type,
      features_snapshot: features,
      trade_executed: trade_executed
    )
  end

  def self.accuracy_rate(bot_id:, from_date: nil, to_date: nil)
    scope = where(bot_id: bot_id, trade_executed: true)
    scope = scope.where("created_at >= ?", from_date) if from_date
    scope = scope.where("created_at <= ?", to_date) if to_date

    total = scope.count
    return 0 if total.zero?

    profitable = scope.where(trade_profitable: true).count
    profitable.to_f / total
  end
end
