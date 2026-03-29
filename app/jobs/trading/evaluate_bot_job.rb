module Trading
  class EvaluateBotJob < ApplicationJob
    queue_as :default

    def perform(bot_id:, timeframe: "1h")
      bot = Bot.find(bot_id)
      return unless bot.active?

      candles = MarketData::QueryService.candles(
        exchange: bot.exchange_name,
        pair: bot.pair,
        interval: timeframe,
        limit: 100
      )

      return if candles.empty?

      indicators = compute_indicators(candles, bot.required_indicators)
      signal = bot.analyze_candles(candles, indicators: indicators)

      ActiveSupport::Notifications.publish("signal.generated", bot_id: bot.id, signal: signal, timeframe: timeframe)

      return if signal.hold?

      if bot.ai_enabled && bot.ml_model_id
        filtered = apply_ml_filter(bot: bot, signal: signal)
        ActiveSupport::Notifications.publish("signal.ml_filtered", bot_id: bot.id, original: signal, filtered: filtered)
        signal = filtered
      end

      return if signal.hold?

      if bot.mode_auto?
        execute_signal(bot: bot, signal: signal)
      else
        request_approval(bot: bot, signal: signal)
      end

      signal
    end

    private

    def compute_indicators(candles, required)
      result = {}
      result[:rsi] = Indicators::RSI.calculate(candles, period: 14) if required.include?(:rsi)

      if required.include?(:macd)
        result[:macd] = Indicators::MACD.calculate(
          candles,
          fast_period: 12,
          slow_period: 26,
          signal_period: 9
        )
      end

      result
    end

    def apply_ml_filter(bot:, signal:)
      return signal if signal.hold?

      prediction = MlAnalytics::Predict.call(bot: bot, signal: signal)

      return signal if prediction.confidence >= bot.ml_high_threshold && signal.buy?
      return signal if prediction.confidence >= bot.ml_high_threshold && signal.sell?
        return Strategy::Signal.new(type: Strategy::Signal::HOLD, confidence: 0, reason: "ML filtered: low confidence #{prediction.confidence}") if prediction.confidence < bot.ml_low_threshold

      signal
    end

    def execute_signal(bot:, signal:)
      Trading::ExecuteSignal.call(bot: bot, signal: signal)
    end

    def request_approval(bot:, signal:)
      Trading::RequestApproval.call(bot: bot, signal: signal)
    end
  end
end
