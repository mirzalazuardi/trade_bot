module Strategy
  class MacdCrossover
    include Strategy::Base

    def self.required_indicators
      [ :macd ]
    end

    def self.params
      { fast_period: 12, slow_period: 26, signal_period: 9 }
    end

    def analyze(candles, indicators: {})
      macd_data = indicators[:macd]
      return Signal.new(type: Strategy::HOLD, confidence: 0, reason: "Insufficient MACD data") if macd_data.nil? || macd_data[:macd_line].empty?

      macd_line = macd_data[:macd_line]
      signal_line = macd_data[:signal_line]

      return Signal.new(type: Strategy::HOLD, confidence: 0, reason: "Insufficient MACD data") if macd_line.length < 2

      current_macd = macd_line.last
      current_signal = signal_line.last
      prev_macd = macd_line[-2]
      prev_signal = signal_line[-2]

      crossed_above = prev_macd < prev_signal && current_macd > current_signal
      crossed_below = prev_macd > prev_signal && current_macd < current_signal

      histogram = current_macd - current_signal

      if crossed_above
        Signal.new(
          type: Strategy::BUY,
          confidence: calculate_confidence(histogram, :bullish),
          reason: "MACD bullish crossover",
          suggested_price: candles.last[:close]
        )
      elsif crossed_below
        Signal.new(
          type: Strategy::SELL,
          confidence: calculate_confidence(histogram, :bearish),
          reason: "MACD bearish crossover",
          suggested_price: candles.last[:close]
        )
      else
        Signal.new(
          type: Strategy::HOLD,
          confidence: 0.5,
          reason: "MACD no crossover"
        )
      end
    end

    private

    def calculate_confidence(histogram, direction)
      normalized = (histogram.abs / 10.0).clamp(0, 1)
      base = direction == :bullish ? 0.6 : 0.6
      (base + normalized * 0.35).clamp(0.6, 0.95)
    end
  end

  Strategy::Registry.register("macd_crossover", MacdCrossover) if defined?(Strategy::Registry)
end
