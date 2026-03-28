module Indicators
  module MACD
    def self.calculate(candles, fast_period: 12, slow_period: 26, signal_period: 9)
      return [] if candles.empty?

      closes = candles.map(&:close)
      return [] if closes.length < slow_period + signal_period

      def self.ema(values, period)
        multiplier = 2 / (period + 1)
        ema_values = [ values.first ]

        (1..values.length - 1).each do |i|
          ema = (values[i] * multiplier) + (ema_values.last * (1 - multiplier))
          ema_values << ema
        end

        ema_values
      end

      fast_ema = ema(closes, fast_period)
      slow_ema = ema(closes, slow_period)

      macd_line = fast_ema.zip(slow_ema).map { |f, s| f - s }

      signal_line = ema(macd_line, signal_period)

      histogram = macd_line.zip(signal_line).map { |m, s| m - s }

      {
        macd_line: macd_line,
        signal_line: signal_line,
        histogram: histogram
      }
    end
  end
end
