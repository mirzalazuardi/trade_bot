# frozen_string_literal: true

module Exchanges
  Ticker = Data.define(:pair, :bid, :ask, :last, :volume_24h, :price_change_24h, :price_change_percent_24h, :high_24h, :low_24h, :timestamp) do
      def initialize(pair:, bid: nil, ask: nil, last: nil, volume_24h: nil, price_change_24h: nil, price_change_percent_24h: nil, high_24h: nil, low_24h: nil, timestamp: nil)
        super
      end

      def spread
        return nil if bid.nil? || ask.nil?
        ask - bid
      end

      def spread_percent
        return nil if spread.nil? || last.nil? || last.zero?
        (spread / last) * 100
      end
  end
end
