module Indicators
  module MovingAverage
    def self.sma(candles, period:)
      closes = candles.map(&:close)
      return [] if closes.length < period

      sma_values = []

      (period - 1..closes.length - 1).each do |i|
        slice = closes[0..i].last(period)
        sma_values << slice.sum / period.to_d
      end

      sma_values
    end

    def self.ema(candles, period:)
      closes = candles.map(&:close)
      return [] if closes.empty?

      multiplier = 2 / (period + 1)
      ema_values = [ closes.first ]

      (1..closes.length - 1).each do |i|
        ema = (closes[i] * multiplier) + (ema_values.last * (1 - multiplier))
        ema_values << ema
      end

      ema_values
    end
  end
end
