module MarketIntelligence
  class MarketContext
    def self.call
      new.call
    end

    def call
      news = NewsService.call
      polymarket = PolymarketService.call

      {
        risk_regime: determine_risk_regime(polymarket),
        calendar_risk: news[:risk_level],
        upcoming_events: news[:upcoming_high_impact],
        avoid_pairs: news[:avoid_pairs],
        polymarket_signals: polymarket[:risk_signals],
        polymarket_shifts: polymarket[:major_shifts],
        bias: determine_bias(polymarket),
        size_modifier: calculate_size_modifier(news, polymarket),
        summary: build_summary(news, polymarket)
      }
    end

    private

    def determine_risk_regime(polymarket)
      signals = polymarket[:risk_signals] || []

      high_impact_count = signals.count { |s| s[:impact] == :high }

      if high_impact_count >= 2
        :risk_off
      elsif high_impact_count == 1
        :mixed
      else
        :risk_on
      end
    end

    def determine_bias(polymarket)
      signals = polymarket[:risk_signals] || []

      fed_hawkish = signals.any? { |s| s[:type] == :monetary_policy && s[:probability] > 0.7 }
      geo_risk = signals.any? { |s| s[:type] == :geopolitical && s[:impact] == :high }
      crypto_positive = signals.any? { |s| s[:type] == :crypto_regulation && s[:probability] > 0.6 }

      if fed_hawkish || geo_risk
        :bearish
      elsif crypto_positive
        :bullish
      else
        :neutral
      end
    end

    def calculate_size_modifier(news, polymarket)
      modifier = 1.0

      modifier *= 0.0 if news[:risk_level] == :high
      modifier *= 0.5 if news[:risk_level] == :medium

      high_impact = (polymarket[:risk_signals] || []).count { |s| s[:impact] == :high }
      modifier *= 0.5 if high_impact >= 2

      modifier.clamp(0.0, 1.0)
    end

    def build_summary(news, polymarket)
      parts = []

      case news[:risk_level]
      when :high
        parts << "HIGH-IMPACT events within 30min — no new positions"
      when :medium
        parts << "Upcoming events — reduce size"
      end

      if news[:avoid_pairs].any?
        parts << "Avoid: #{news[:avoid_pairs].join(', ')}"
      end

      (polymarket[:risk_signals] || []).first(3).each do |signal|
        parts << "#{signal[:type]}: #{signal[:title]} (#{(signal[:probability] * 100).round}%)"
      end

      (polymarket[:major_shifts] || []).first(2).each do |shift|
        parts << "Shift: #{shift[:question]} → #{shift[:direction]} (#{(shift[:probability] * 100).round}%)"
      end

      parts.empty? ? "Markets calm. Normal trading conditions." : parts.join(" | ")
    end
  end
end
