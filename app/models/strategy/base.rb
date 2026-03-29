module Strategy
  module Base
    def analyze(candles, indicators: {})
      raise NotImplementedError, "#{self.class} must implement #analyze"
    end

    module ClassMethods
      def required_indicators
        []
      end

      def params
        {}
      end

      def required_timeframes
        [ "1h" ]
      end

      def registry_name
        name.split("::").last.underscore
      end
    end
  end

  BUY = "buy"
  SELL = "sell"
  HOLD = "hold"

  Signal = Data.define(:type, :confidence, :reason, :suggested_price) do
    def initialize(type:, confidence: 0.5, reason: nil, suggested_price: nil)
      super
    end

    def buy?
      type == Strategy::BUY
    end

    def sell?
      type == Strategy::SELL
    end

    def hold?
      type == Strategy::HOLD
    end

    def strong?
      confidence >= 0.7
    end

    def weak?
      confidence < 0.4
    end
  end
end
