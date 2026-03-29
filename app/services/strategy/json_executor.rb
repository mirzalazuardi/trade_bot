module Strategy
  class JsonExecutor
    def self.call(config:, candles:, indicators:)
      new(config: config, candles: candles, indicators: indicators).execute
    end

    def initialize(config:, candles:, indicators:)
      @config = config
      @candles = candles
      @indicators = indicators
      @params = config["parameters"] || {}
    end

    def execute
      signal = detect_signal
      return Strategy::Signal.new(type: Strategy::Signal::HOLD, confidence: 0, reason: "No signal") unless signal

      Signal.new(
        type: signal[:type],
        confidence: evaluate_expression(signal[:confidence] || 0.5),
        reason: signal[:reason],
        suggested_price: @candles.last[:close]
      )
    end

    private

    def detect_signal
      entry = @config["entry"] || {}

      if evaluate_condition(entry.dig("buy", "condition"))
        { type: Signal::BUY, reason: "Entry: #{entry.dig('buy', 'condition')}", confidence: entry.dig("buy", "confidence") || 0.7 }
      elsif evaluate_condition(entry.dig("sell", "condition"))
        { type: Signal::SELL, reason: "Entry: #{entry.dig('sell', 'condition')}", confidence: entry.dig("sell", "confidence") || 0.7 }
      elsif (exit = @config["exit"])
        if evaluate_condition(exit["buy"])
          { type: Signal::SELL, reason: "Exit buy: #{exit['buy']}", confidence: 0.6 }
        elsif evaluate_condition(exit["sell"])
          { type: Signal::BUY, reason: "Exit sell: #{exit['sell']}", confidence: 0.6 }
        end
      end
    end

    def evaluate_condition(condition)
      return false if condition.nil? || condition.empty?

      expr = replace_params(condition)
      evaluate_expression(expr) rescue false
    end

    def replace_params(expr)
      @params.each do |key, value|
        expr = expr.gsub("{{#{key}}}", value.to_s)
      end
      expr
    end

    def evaluate_expression(expr)
      rsi = @indicators[:rsi]&.last || 50
      macd = @indicators[:macd]&.dig(:macd)&.last || 0
      signal = @indicators[:macd]&.dig(:signal)&.last || 0

      prev_rsi = @indicators[:rsi]&.[-2] || rsi
      prev_macd = @indicators[:macd]&.dig(:macd)&.-2 || macd
      prev_signal = @indicators[:macd]&.dig(:signal)&.-2 || signal

      candle = @candles.last

      eval(expr)
    rescue
      false
    end
  end
end
