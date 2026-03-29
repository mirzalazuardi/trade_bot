module Indicators
  class Pipeline
    ResultStruct = Struct.new(
      :rsi, :macd, :macd_signal, :macd_histogram, :sma_20, :sma_50, :bb_upper, :bb_middle, :bb_lower
    ) do
      def dig(key, idx)
        val = send(key)
        return nil if val.nil? || val.empty?
        val[idx]
      end
    end

    def self.build(candles)
      new(candles).calculate
    end

    def initialize(candles)
      @candles = candles.map { |c| c.is_a?(Hash) ? c.with_indifferent_access : c }
    end

    def calculate
      rsi = RSI.calculate(@candles, period: 14)
      macd = MACD.calculate(@candles)
      bb = BollingerBands.calculate(@candles)
      sma_20 = MovingAverage.sma(@candles, period: 20)
      sma_50 = MovingAverage.sma(@candles, period: 50)

      ResultStruct.new(
        rsi,
        macd[:macd_line],
        macd[:signal_line],
        macd[:histogram],
        sma_20,
        sma_50,
        bb[:upper],
        bb[:middle],
        bb[:lower]
      )
    end
  end
end
