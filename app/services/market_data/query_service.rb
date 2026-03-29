module MarketData
  class QueryService
    def self.candles(exchange:, pair:, interval:, from: nil, to: nil, limit: nil)
      query = Candle.by_exchange(exchange).by_pair(pair).by_interval(interval)

      if from
        query = query.where("timestamp >= ?", from.to_time.to_i)
      end

      if to
        query = query.where("timestamp <= ?", to.to_time.to_i)
      end

      query = query.order(timestamp: :desc)
      query = query.limit(limit) if limit

      query.reverse_order
    end

    def self.ticker(exchange:, pair:)
      Ticker.by_exchange(exchange).by_pair(pair).recent.first
    end

    def self.latest_price(exchange:, pair:)
      ticker(exchange: exchange, pair: pair)&.last ||
        candles(exchange: exchange, pair: pair, interval: "1m", limit: 1).first&.close
    end

    def self.price_range(exchange:, pair:, interval:, days:)
      from = days.days.ago
      candles = self.candles(exchange: exchange, pair: pair, interval: interval, from: from)

      return nil if candles.empty?

      {
        high: candles.map(&:high).max,
        low: candles.map(&:low).min,
        open: candles.first.open,
        close: candles.last.close
      }
    end
  end
end
