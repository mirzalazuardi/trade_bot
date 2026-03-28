module Features
  class FractionalDiff
    def self.call(candles, d: 0.4, threshold: 1e-5)
      new(candles: candles, d: d, threshold: threshold).compute
    end

    def initialize(candles:, d:, threshold:)
      @closes = candles.map(&:close).map(&:to_f)
      @d = d
      @threshold = threshold
    end

    def compute
      weights = compute_weights
      return @closes if weights.length < 2

      ffd(@closes, weights)
    end

    private

    # AFML Ch.5 — Fixed-width window fractional differentiation
    # w_0 = 1, w_k = -w_{k-1} * (d - k + 1) / k
    def compute_weights
      weights = [ 1.0 ]
      k = 1
      loop do
        w = -weights.last * (@d - k + 1) / k
        break if w.abs < @threshold
        weights << w
        k += 1
      end
      weights
    end

    def ffd(series, weights)
      output = []

      series.each_with_index do |_, i|
        val = 0.0
        weights.each_with_index do |w, j|
          break if i - j < 0
          val += w * series[i - j]
        end
        output << val
      end

      output
    end
  end
end
