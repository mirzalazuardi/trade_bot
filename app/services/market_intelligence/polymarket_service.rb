module MarketIntelligence
  class PolymarketService
    GAMMA_API = "https://gamma-api.polymarket.com"

    TRACKED_TAGS = %w[
      politics economics fed-reserve inflation interest-rates
      geopolitics elections crypto regulation tariffs
    ].freeze

    def self.call
      new.call
    end

    def call
      events = fetch_tracked_events
      {
        events: events,
        major_shifts: detect_shifts(events),
        risk_signals: extract_risk_signals(events)
      }
    end

    private

    def fetch_tracked_events
      events = []

      TRACKED_TAGS.each do |tag|
        response = http_client.get("/events", params: {
          tag: tag,
          limit: 5,
          active: true,
          order: "volume24hr",
          ascending: false
        })

        next unless response.success?

        parsed = JSON.parse(response.body)
        parsed.each do |event|
          markets = event["markets"] || []
          markets.each do |market|
            next unless market["active"]

            outcome_prices = market["outcomePrices"]
            next unless outcome_prices

            prices = JSON.parse(outcome_prices) rescue []
            yes_price = prices[0]&.to_f

            events << {
              id: event["id"],
              title: event["title"],
              slug: event["slug"],
              tag: tag,
              market_question: market["question"],
              yes_price: yes_price,
              no_price: prices[1]&.to_f,
              volume_24h: market["volume24hr"]&.to_f || 0,
              volume_total: market["volume"]&.to_f || 0,
              liquidity: market["liquidity"]&.to_f || 0,
              end_date: market["endDate"],
              url: "https://polymarket.com/event/#{event['slug']}"
            }
          end
        end
      rescue Faraday::Error
        next
      end

      events
        .uniq { |e| e[:market_question] }
        .sort_by { |e| -e[:volume_24h] }
        .first(20)
    end

    def detect_shifts(events)
      events.select do |event|
        event[:yes_price] && (event[:yes_price] > 0.9 || event[:yes_price] < 0.1)
      end.map do |event|
        {
          title: event[:title],
          question: event[:market_question],
          probability: event[:yes_price],
          direction: event[:yes_price] > 0.5 ? "likely" : "unlikely",
          url: event[:url]
        }
      end
    end

    def extract_risk_signals(events)
      signals = []

      fed_events = events.select { |e| e[:tag].include?("fed") || e[:tag].include?("interest") }
      fed_events.each do |event|
        if event[:yes_price] && event[:yes_price] > 0.7
          signals << {
            type: :monetary_policy,
            title: event[:market_question],
            probability: event[:yes_price],
            impact: :high,
            affected: %w[EUR/USD GBP/USD USD/JPY XAU/USD BTC/USDT]
          }
        end
      end

      geo_events = events.select { |e| e[:tag] == "geopolitics" || e[:tag] == "tariffs" }
      geo_events.each do |event|
        if event[:yes_price] && event[:volume_24h] > 50_000
          signals << {
            type: :geopolitical,
            title: event[:market_question],
            probability: event[:yes_price],
            impact: event[:volume_24h] > 500_000 ? :high : :medium,
            affected: %w[XAU/USD EUR/USD BTC/USDT]
          }
        end
      end

      crypto_events = events.select { |e| e[:tag] == "crypto" || e[:tag] == "regulation" }
      crypto_events.each do |event|
        if event[:yes_price] && event[:volume_24h] > 100_000
          signals << {
            type: :crypto_regulation,
            title: event[:market_question],
            probability: event[:yes_price],
            impact: :high,
            affected: %w[BTC/USDT ETH/USDT SOL/USDT BNB/USDT]
          }
        end
      end

      signals
    end

    def http_client
      @http_client ||= Faraday.new(url: GAMMA_API) do |f|
        f.request :retry, max: 2, interval: 0.5
        f.options.timeout = 10
        f.options.open_timeout = 5
      end
    end
  end
end
