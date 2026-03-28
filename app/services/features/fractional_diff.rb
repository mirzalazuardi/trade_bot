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
      return @closes if weights.empty?

      convolve(@closes, weights)
    end

    private

    def compute_weights
      weights = []
      k = 0
      while true
        w = gamma_function(k - @d + 1) / (Math::PI * gamma_function(k + 1))
        break if w.abs < @threshold
        weights << w
        k += 1
      end
      weights
    end

    def gamma_function(n)
      return Math.sqrt(Math::PI) if n == 0.5
      return 1 if n == 1
      return Math::PI / Math.sin(Math::PI * n) if n < 0

      result = 1
      (1...n.to_i).each { |i| result *= i }
      result
    end

    def convolve(signal, kernel)
      output = []
      signal.each_with_index do |_, i|
        sum = 0
        kernel.each_with_index do |w, j|
          break if i - j < 0
          sum += signal[i - j] * w
        end
        output << sum
      end
      output
    end
  end
end
