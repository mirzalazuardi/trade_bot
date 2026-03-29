module Indicators
  module BollingerBands
    def self.calculate(candles, period: 20, std_dev: 2)
      return { upper: [], middle: [], lower: [] } if candles.empty?

      closes = candles.map { |c| c.respond_to?(:close) ? c.close : c[:close] }
      return { upper: [], middle: [], lower: [] } if closes.length < period

      upper = []
      middle = []
      lower = []

      (period - 1..closes.length - 1).each do |i|
        slice = closes[0..i]
        sma = slice.last(period).sum / period.to_d

        variance = slice.last(period).map { |c| (c - sma)**2 }.sum / period.to_d
        sd = Math.sqrt(variance)

        middle << sma
        upper << sma + (std_dev * sd)
        lower << sma - (std_dev * sd)
      end

      { upper: upper, middle: middle, lower: lower }
    end
  end
end
