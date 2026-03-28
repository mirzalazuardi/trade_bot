module CustomAssertions
  def build_candle_data(closes)
    closes.map.with_index do |close, i|
      OpenStruct.new(
        open: close * 0.99,
        high: close * 1.01,
        low: close * 0.98,
        close: close,
        volume: 1000,
        timestamp: i
      )
    end
  end

  def assert_signal(signal, type:)
    assert_equal type, signal.type, "Expected signal type #{type}, got #{signal.type}"
  end

  def assert_in_epsilon(expected, actual, epsilon = 0.001)
    assert (expected - actual).abs < epsilon, "Expected #{expected}, got #{actual}"
  end

  def calculate_variance(values)
    return 0 if values.empty?
    mean = values.sum / values.size
    values.sum { |v| (v - mean)**2 } / values.size
  end
end
