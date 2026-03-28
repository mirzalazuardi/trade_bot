module Strategy
  module Base
    extend ActiveSupport::Concern

    included do
      extend Strategy::Base::ClassMethods
    end

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
end

Signal = Data.define(:type, :confidence, :reason, :suggested_price) do
  BUY = "buy"
  SELL = "sell"
  HOLD = "hold"

  def initialize(type:, confidence: 0.5, reason: nil, suggested_price: nil)
    super
  end

  def buy?
    type == BUY
  end

  def sell?
    type == SELL
  end

  def hold?
    type == HOLD
  end

  def strong?
    confidence >= 0.7
  end

  def weak?
    confidence < 0.4
  end
end
