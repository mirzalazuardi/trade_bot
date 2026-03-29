module Strategy
  class RsiReversal
    include Strategy::Base

    OVERBOUGHT = 70
    OVERSOLD = 30

    def self.required_indicators
      [ :rsi ]
    end

    def self.params
      { period: 14, overbought: OVERBOUGHT, oversold: OVERSOLD }
    end

    def analyze(candles, indicators: {})
      rsi_values = indicators[:rsi]
      return Signal.new(type: Strategy::HOLD, confidence: 0, reason: "Insufficient RSI data") if rsi_values.nil? || rsi_values.empty?

      current_rsi = rsi_values.last
      strategy_params = self.class.params

      if current_rsi <= strategy_params[:oversold]
        Signal.new(
          type: Strategy::BUY,
          confidence: calculate_confidence(current_rsi, :oversold),
          reason: "RSI oversold: #{current_rsi.round(2)}",
          suggested_price: candles.last[:close]
        )
      elsif current_rsi >= strategy_params[:overbought]
        Signal.new(
          type: Strategy::SELL,
          confidence: calculate_confidence(current_rsi, :overbought),
          reason: "RSI overbought: #{current_rsi.round(2)}",
          suggested_price: candles.last[:close]
        )
      else
        Signal.new(type: Strategy::HOLD, confidence: 0.5, reason: "RSI neutral: #{current_rsi.round(2)}")
      end
    end

    private

    def calculate_confidence(rsi, condition)
      if condition == :oversold
        ((30 - rsi) / 30.0 * 0.5 + 0.5).clamp(0.5, 0.95)
      else
        ((rsi - 70) / 30.0 * 0.5 + 0.5).clamp(0.5, 0.95)
      end
    end
  end

  Strategy::Registry.register("rsi_reversal", RsiReversal) if defined?(Strategy::Registry)
end
