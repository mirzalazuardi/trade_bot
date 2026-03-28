module Features
  class Microstructure
    def self.bid_ask_spread_ratio(candles)
      candles.map do |c|
        next 0 if c.high.zero? || c.low.zero?
        (c.high - c.low) / c.close
      end
    end

    def self.order_flow_imbalance(candles, window: 10)
      candles.each_cons(window).map do |slice|
        buy_volume = slice.select { |c| c.close >= c.open }.sum(&:volume)
        sell_volume = slice.select { |c| c.close < c.open }.sum(&:volume)
        total = buy_volume + sell_volume
        total.zero? ? 0 : (buy_volume - sell_volume) / total
      end
    end

    def self.volume_weighted_price(candles, window: 20)
      candles.each_cons(window).map do |slice|
        vwap = slice.sum { |c| c.close * c.volume }
        volume_total = slice.sum(&:volume)
        volume_total.zero? ? 0 : vwap / volume_total
      end
    end
  end
end
