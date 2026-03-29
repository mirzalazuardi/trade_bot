module Trading
  module Strategies
    class JsonExecutor
      OPERATORS = {
        ">" => :>,
        ">=" => :>=,
        "<" => :<,
        "<=" => :<=,
        "==" => :==
      }.freeze

      def self.call(config:, candles:, indicators:)
        new(config: config, candles: candles, indicators: indicators).execute
      end

      def initialize(config:, candles:, indicators:)
        @config = config
        @candles = candles
        @indicators = indicators
        @params = config["parameters"] || {}
        @vars = build_variables
      end

      def execute
        signal = detect_signal
        return Strategy::Signal.new(type: Strategy::HOLD, confidence: 0, reason: "No signal") unless signal

        confidence = resolve_confidence(signal[:raw_confidence]).clamp(0.0, 1.0)

        Strategy::Signal.new(
          type: signal[:type],
          confidence: confidence,
          reason: signal[:reason],
          suggested_price: @candles.last[:close]
        )
      end

      private

      def build_variables
        close_prices = @candles.map { |c| c[:close] }
        high_prices = @candles.map { |c| c[:high] }
        low_prices = @candles.map { |c| c[:low] }
        volumes = @candles.map { |c| c[:volume] }

        if @indicators.is_a?(Hash)
          rsi_values = @indicators[:rsi] || []
          macd_values = @indicators.dig(:macd, :macd_line) || []
          signal_values = @indicators.dig(:macd, :signal_line) || []
          histogram_values = @indicators.dig(:macd, :histogram) || []
          ema_20 = @indicators[:ema_20]&.last
          bb_upper = @indicators.dig(:bb_upper)&.last
          bb_lower = @indicators.dig(:bb_lower)&.last
          bb_middle = @indicators.dig(:bb_middle)&.last
        else
          rsi_values = @indicators.respond_to?(:rsi) ? @indicators.rsi : []
          macd_values = @indicators.respond_to?(:macd) ? @indicators.macd : []
          signal_values = @indicators.respond_to?(:macd_signal) ? @indicators.macd_signal : []
          histogram_values = @indicators.respond_to?(:macd_histogram) ? @indicators.macd_histogram : []
          ema_20 = @indicators.respond_to?(:ema_20) ? @indicators.ema_20&.last : nil
          bb_upper = @indicators.respond_to?(:bb_upper) ? @indicators.bb_upper&.last : nil
          bb_lower = @indicators.respond_to?(:bb_lower) ? @indicators.bb_lower&.last : nil
          bb_middle = @indicators.respond_to?(:bb_middle) ? @indicators.bb_middle&.last : nil
        end

        sma_20 = close_prices.last(20).sum.to_f / [ close_prices.last(20).size, 1 ].max
        sma_50 = close_prices.last(50).sum.to_f / [ close_prices.last(50).size, 1 ].max
        ema_20 ||= sma_20

        bb_upper ||= sma_20 + 2 * stddev(close_prices.last(20))
        bb_lower ||= sma_20 - 2 * stddev(close_prices.last(20))
        bb_middle ||= sma_20

        atr_values = calculate_atr(high_prices, low_prices, close_prices, @params["atr_period"] || 14)

        avg_volume = volumes.last(20).sum.to_f / [ volumes.last(20).size, 1 ].max

        {
          "close" => close_prices.last || 0,
          "prev_close" => close_prices[-2] || 0,
          "open" => @candles.last&.dig(:open) || 0,
          "high" => @candles.last&.dig(:high) || 0,
          "low" => @candles.last&.dig(:low) || 0,
          "volume" => volumes.last || 0,
          "avg_volume" => avg_volume,
          "volume_ratio" => avg_volume > 0 ? (volumes.last || 0).to_f / avg_volume : 1,
          "rsi" => rsi_values.last || 50,
          "prev_rsi" => rsi_values[-2] || 50,
          "macd" => macd_values.last || 0,
          "macd_signal" => signal_values.last || 0,
          "macd_histogram" => histogram_values.last || 0,
          "prev_macd" => macd_values[-2] || 0,
          "prev_macd_signal" => signal_values[-2] || 0,
          "prev_macd_histogram" => histogram_values[-2] || 0,
          "sma_20" => sma_20,
          "sma_50" => sma_50,
          "ema_20" => ema_20,
          "bb_upper" => bb_upper,
          "bb_lower" => bb_lower,
          "bb_middle" => bb_middle,
          "bb_width" => bb_upper && bb_lower ? (bb_upper - bb_lower) / bb_middle : 0,
          "atr" => atr_values.last || 0,
          "prev_atr" => atr_values[-2] || 0
        }
      end

      def detect_signal
        rules = @config["rules"] || []
        entry = @config["entry"] || {}

        if rules.any?
          evaluate_rules(rules)
        else
          evaluate_entry_exit(entry)
        end
      end

      def evaluate_rules(rules)
        rules.each do |rule|
          conditions = rule["conditions"] || []
          next unless conditions.all? { |c| evaluate_single_condition(c) }

          return {
            type: rule["action"] == "buy" ? Strategy::BUY : Strategy::SELL,
            reason: rule["name"] || "Rule matched",
            raw_confidence: rule["confidence"] || 0.7
          }
        end

        nil
      end

      def evaluate_entry_exit(entry)
        if entry["buy"] && evaluate_all_conditions(entry.dig("buy", "conditions") || [ entry.dig("buy", "condition") ])
          { type: Strategy::BUY, reason: format_reason("buy", entry["buy"]), raw_confidence: entry.dig("buy", "confidence") || 0.7 }
        elsif entry["sell"] && evaluate_all_conditions(entry.dig("sell", "conditions") || [ entry.dig("sell", "condition") ])
          { type: Strategy::SELL, reason: format_reason("sell", entry["sell"]), raw_confidence: entry.dig("sell", "confidence") || 0.7 }
        end
      end

      def evaluate_all_conditions(conditions)
        conditions.compact.all? { |c| evaluate_single_condition(c) }
      end

      def evaluate_single_condition(condition)
        return false if condition.nil?

        if condition.is_a?(Hash)
          left = resolve_value(condition["left"])
          right = resolve_value(condition["right"])
          op = condition["op"]
          return false unless OPERATORS.key?(op)

          left.send(OPERATORS[op], right)
        elsif condition.is_a?(String)
          parse_simple_condition(condition)
        else
          false
        end
      rescue
        false
      end

      def parse_simple_condition(expr)
        expr = replace_params(expr)

        OPERATORS.each do |op_str, op_sym|
          next unless expr.include?(op_str)

          parts = expr.split(op_str, 2).map(&:strip)
          next if parts.size != 2

          left = resolve_value(parts[0])
          right = resolve_value(parts[1])
          return left.send(op_sym, right)
        end

        false
      end

      def resolve_value(val)
        return val if val.is_a?(Numeric)

        val = val.to_s.strip
        val = replace_params(val)

        return val.to_f if val.match?(/\A-?\d+(\.\d+)?\z/)

        if val.include?("*")
          parts = val.split("*").map { |v| resolve_value(v.strip) }
          return parts.reduce(:*)
        end

        if val.include?("+")
          parts = val.split("+").map { |v| resolve_value(v.strip) }
          return parts.reduce(:+)
        end

        if val.include?("-") && !val.start_with?("-")
          parts = val.split("-", 2).map { |v| resolve_value(v.strip) }
          return parts[0] - parts[1]
        end

        @vars[val]&.to_f || 0.0
      end

      def resolve_confidence(conf)
        return conf.to_f if conf.is_a?(Numeric)
        resolve_value(conf)
      end

      def replace_params(expr)
        result = expr.to_s
        @params.each do |key, value|
          result = result.gsub("{{#{key}}}", value.to_s)
        end
        result
      end

      def format_reason(side, config)
        config["name"] || config["condition"] || "#{side} signal"
      end

      def calculate_atr(highs, lows, closes, period)
        return [] if highs.size < 2

        trs = (1...highs.size).map do |i|
          [
            highs[i] - lows[i],
            (highs[i] - closes[i - 1]).abs,
            (lows[i] - closes[i - 1]).abs
          ].max
        end

        return [] if trs.size < period

        atrs = [ trs.first(period).sum / period.to_f ]
        trs[period..].each do |tr|
          atrs << (atrs.last * (period - 1) + tr) / period.to_f
        end

        atrs
      end

      def stddev(values)
        return 0 if values.empty?
        mean = values.sum / values.size.to_f
        variance = values.sum { |v| (v - mean) ** 2 } / values.size.to_f
        Math.sqrt(variance)
      end
    end
  end
end
