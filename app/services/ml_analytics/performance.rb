module MlAnalytics
  class Performance
    def self.call(user:, bot_id: nil, ml_model_id: nil, from_date: nil, to_date: nil)
      new(user: user, bot_id: bot_id, ml_model_id: ml_model_id, from_date: from_date, to_date: to_date).compute
    end

    def initialize(user:, bot_id:, ml_model_id:, from_date:, to_date:)
      @user = user
      @bot_id = bot_id
      @ml_model_id = ml_model_id
      @from_date = from_date
      @to_date = to_date
    end

    def compute
      stats = base_stats.merge(confidence_distribution).merge(outcome_metrics)
      Metrics.new(**stats)
    end

    private

    def base_scope
      scope = @user.ml_prediction_logs
      scope = scope.where(bot_id: @bot_id) if @bot_id
      scope = scope.where(ml_model_id: @ml_model_id) if @ml_model_id
      scope = scope.where("created_at >= ?", @from_date) if @from_date
      scope = scope.where("created_at <= ?", @to_date) if @to_date
      scope
    end

    def base_stats
      total_predictions = base_scope.count
      executed = base_scope.where(trade_executed: true).count
      filtered = total_predictions - executed

      {
        total_predictions: total_predictions,
        executed_signals: executed,
        filtered_signals: filtered,
        filter_rate: total_predictions > 0 ? filtered.to_f / total_predictions : 0.0
      }
    end

    def confidence_distribution
      bins = { low: 0, moderate: 0, high: 0 }
      base_scope.each do |log|
        case log.confidence
        when 0.0..0.3 then bins[:low] += 1
        when 0.3..0.7 then bins[:moderate] += 1
        else bins[:high] += 1
        end
      end
      bins
    end

    def outcome_metrics
      executed = base_scope.where(trade_executed: true)
      total_executed = executed.count
      return empty_outcomes if total_executed.zero?

      profitable = executed.where(trade_profitable: true).count
      losers = total_executed - profitable

      {
        accuracy: profitable.to_f / total_executed,
        profitable_trades: profitable,
        losing_trades: losers
      }
    end

    def empty_outcomes
      { accuracy: 0.0, profitable_trades: 0, losing_trades: 0 }
    end

    Metrics = Data.define(
      :total_predictions,
      :executed_signals,
      :filtered_signals,
      :filter_rate,
      :low,
      :moderate,
      :high,
      :accuracy,
      :profitable_trades,
      :losing_trades
    )

    def empty_outcomes
      { accuracy: 0.0, profitable_trades: 0, losing_trades: 0 }
    end
  end
end
