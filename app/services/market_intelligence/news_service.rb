module MarketIntelligence
  class NewsService
    BASE_URL = "https://nfs.faireconomy.media/ff_calendar_thisweek.json"

    IMPACT_MAP = {
      "High" => :high,
      "Medium" => :medium,
      "Low" => :low,
      "Holiday" => :holiday
    }.freeze

    CURRENCY_TO_PAIRS = {
      "USD" => %w[EUR/USD GBP/USD USD/JPY USD/CHF AUD/USD USD/CAD XAU/USD],
      "EUR" => %w[EUR/USD EUR/GBP EUR/JPY],
      "GBP" => %w[GBP/USD EUR/GBP GBP/JPY],
      "JPY" => %w[USD/JPY EUR/JPY GBP/JPY],
      "AUD" => %w[AUD/USD AUD/JPY],
      "CAD" => %w[USD/CAD CAD/JPY],
      "CHF" => %w[USD/CHF EUR/CHF]
    }.freeze

    def self.call
      new.call
    end

    def call
      events = fetch_calendar
      {
        events: events,
        upcoming_high_impact: upcoming_high_impact(events),
        risk_level: calculate_risk_level(events),
        avoid_pairs: pairs_to_avoid(events)
      }
    end

    private

    def fetch_calendar
      response = Faraday.get(BASE_URL)
      return [] unless response.success?

      JSON.parse(response.body).map do |event|
        event_time = parse_event_time(event["date"], event["time"])
        next unless event_time

        {
          title: event["title"],
          country: event["country"],
          impact: IMPACT_MAP[event["impact"]] || :low,
          time: event_time,
          forecast: event["forecast"],
          previous: event["previous"],
          actual: event["actual"],
          minutes_until: ((event_time - Time.current) / 60).round
        }
      end.compact.sort_by { |e| e[:time] }
    rescue Faraday::Error
      []
    end

    def parse_event_time(date_str, time_str)
      return nil if date_str.blank?

      if time_str.present? && time_str != "All Day"
        Time.zone.parse("#{date_str} #{time_str}")
      else
        Time.zone.parse(date_str)
      end
    rescue ArgumentError
      nil
    end

    def upcoming_high_impact(events, window_minutes: 240)
      events.select do |e|
        e[:impact] == :high &&
          e[:minutes_until] > -30 &&
          e[:minutes_until] < window_minutes
      end
    end

    def calculate_risk_level(events)
      upcoming = upcoming_high_impact(events, window_minutes: 60)

      if upcoming.any? { |e| e[:minutes_until].between?(-5, 30) }
        :high
      elsif upcoming.any?
        :medium
      else
        :low
      end
    end

    def pairs_to_avoid(events)
      upcoming = upcoming_high_impact(events, window_minutes: 30)
      pairs = upcoming.flat_map do |event|
        CURRENCY_TO_PAIRS[event[:country]] || []
      end
      pairs.uniq
    end
  end
end
