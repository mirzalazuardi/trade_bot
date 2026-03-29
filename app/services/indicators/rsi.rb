module Indicators
  module RSI
    def self.calculate(candles, period: 14)
      return [] if candles.empty?

      closes = candles.map { |c| c.respond_to?(:close) ? c.close : c[:close] }
      return [] if closes.length < period + 1

      gains = []
      losses = []

      (1..closes.length - 1).each do |i|
        change = closes[i] - closes[i - 1]
        gains << (change > 0 ? change : 0)
        losses << (change < 0 ? -change : 0)
      end

      avg_gain = gains[0, period].sum / period.to_d
      avg_loss = losses[0, period].sum / period.to_d

      rsi_values = []

      if avg_loss.zero?
        rsi_values << 100
      else
        rs = avg_gain / avg_loss
        rsi_values << 100 - (100 / (1 + rs))
      end

      (period..gains.length - 1).each do |i|
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period.to_d
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period.to_d

        if avg_loss.zero?
          rsi_values << 100
        else
          rs = avg_gain / avg_loss
          rsi_values << 100 - (100 / (1 + rs))
        end
      end

      rsi_values
    end
  end
end
