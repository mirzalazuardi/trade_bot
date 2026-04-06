# frozen_string_literal: true

module Exchanges
  Candle = Data.define(:pair, :interval, :open, :high, :low, :close, :volume, :timestamp, :closed) do
      def initialize(pair:, interval:, open:, high:, low:, close:, volume:, timestamp:, closed: true)
        super
      end

      def to_h
        { pair: pair, interval: interval, open: open, high: high, low: low, close: close, volume: volume, timestamp: timestamp, closed: closed }
      end
  end
end
