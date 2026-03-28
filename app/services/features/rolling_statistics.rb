module Features
  class RollingStatistics
    def self.volatility(candles, window: 20)
      returns = calculate_returns(candles)
      rolling_stdev(returns, window)
    end

    def self.correlation(asset1_candles, asset2_candles, window: 20)
      returns1 = calculate_returns(asset1_candles)
      returns2 = calculate_returns(asset2_candles)
      min_len = [ returns1.length, returns2.length ].min

      return [] if min_len < window

      correlation = []
      (window - 1...min_len).each do |i|
        slice1 = returns1[(i - window + 1)..i]
        slice2 = returns2[(i - window + 1)..i]
        correlation << pearson_correlation(slice1, slice2)
      end
      correlation
    end

    def self.sharpe(candles, window: 20, risk_free_rate: 0.02 / 252)
      returns = calculate_returns(candles)
      return [] if returns.length < window

      sharpe = []
      (window - 1...returns.length).each do |i|
        slice = returns[(i - window + 1)..i]
        mean_return = slice.sum / window
        std_return = Math.sqrt(rolling_variance(slice).last || 0)
        next if std_return.zero?

        annualized = (mean_return - risk_free_rate) * Math.sqrt(252)
        sharpe << annualized / std_return
      end
      sharpe
    end

    private

    def self.calculate_returns(candles)
      closes = candles.map(&:close).map(&:to_f)
      closes.each_cons(2).map { |a, b| (b - a) / a }
    end

    def self.rolling_stdev(values, window)
      stdev = []
      (window - 1...values.length).each do |i|
        slice = values[(i - window + 1)..i]
        variance = rolling_variance(slice).last || 0
        stdev << Math.sqrt(variance)
      end
      stdev
    end

    def self.rolling_variance(values)
      return [] if values.empty?

      mean = 0
      m2 = 0
      variance = []

      values.each_with_index do |value, i|
        delta = value - mean
        mean += delta / (i + 1)
        delta2 = value - mean
        m2 += delta * delta2
        variance << m2 / (i + 1) if i >= 0
      end
      variance
    end

    def self.pearson_correlation(x, y)
      return 0 if x.length != y.length || x.empty?

      n = x.length
      mean_x = x.sum / n
      mean_y = y.sum / n

      numerator = x.zip(y).sum { |xi, yi| (xi - mean_x) * (yi - mean_y) }
      denom_x = Math.sqrt(x.sum { |xi| (xi - mean_x)**2 })
      denom_y = Math.sqrt(y.sum { |yi| (yi - mean_y)**2 })

      return 0 if denom_x.zero? || denom_y.zero?
      numerator / (denom_x * denom_y)
    end
  end
end
