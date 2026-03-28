module Features
  class Pipeline
    def self.call(exchange:, pair:, ml_model_id:)
      new(exchange: exchange, pair: pair, ml_model_id: ml_model_id).compute
    end

    def initialize(exchange:, pair:, ml_model_id:)
      @exchange = exchange
      @pair = pair
      @ml_model = MlModel.find(ml_model_id)
      @candles = fetch_candles
    end

    def compute
      insufficient_data? ? nil : build_feature_vector
    end

    private

    def fetch_candles
      limit = (@ml_model.feature_list.length * 3).clamp(50, 500)
      MarketData::QueryService.candles(exchange: @exchange, pair: @pair, interval: "1h", limit: limit)
    end

    def insufficient_data?
      @candles.length < 50
    end

    def build_feature_vector
      features = []

      if @ml_model.feature_list.include?("ffd")
        ffd = FractionalDiff.call(@candles, d: 0.4)
        features.concat(ffd.last(20))
      end

      if @ml_model.feature_list.include?("volatility")
        vol = RollingStatistics.volatility(@candles, window: 20)
        features.concat(vol.last(10))
      end

      if @ml_model.feature_list.include?("spread")
        spread = Microstructure.bid_ask_spread_ratio(@candles)
        features.concat(spread.last(10))
      end

      if @ml_model.feature_list.include?("vwap")
        vwap = Microstructure.volume_weighted_price(@candles, window: 20)
        features.concat(vwap.last(10))
      end

      if @ml_model.feature_list.include?("rsi")
        rsi = Indicators::RSI.calculate(@candles, period: 14)
        features.concat(rsi.last(5))
      end

      features.map(&:to_f)
    end
  end
end
