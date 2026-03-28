module Exchanges
  class Oanda
    include Base

    BASE_URLS = {
      practice: "https://api-fxpractice.oanda.com",
      live: "https://api-fxtrade.oanda.com"
    }

    attr_reader :api_key, :account_id, :environment, :http_client

    def initialize(api_key: nil, account_id: nil, environment: :practice)
      @api_key = api_key
      @account_id = account_id
      @environment = environment
      @http_client = HttpClient.new(
        base_url: BASE_URLS[environment],
        api_key: api_key
      )
    end

    def self.required_credentials
      %i[api_key account_id]
    end

    def self.supported_pairs
      %w[EUR/USD GBP/USD USD/JPY AUD/USD USD/CAD USD/CHF
         EUR/GBP EUR/JPY GBP/JPY XAU/USD XAG/USD]
    end

    def normalize_pair(pair)
      pair.gsub("/", "_")
    end

    def denormalize_pair(pair)
      pair.gsub("_", "/")
    end

    def fetch_ticker(pair)
      instrument = normalize_pair(pair)
      data = http_client.get("/v3/accounts/#{account_id}/pricing", params: {
        instruments: instrument
      })

      price_data = data[:prices].first

      bid = price_data[:bids]&.first&.dig(:price)&.to_d
      ask = price_data[:asks]&.first&.dig(:price)&.to_d

      Ticker.new(
        pair: pair,
        bid: bid,
        ask: ask,
        last: ((bid + ask) / 2 if bid && ask),
        volume_24h: nil,
        price_change_24h: nil,
        price_change_percent_24h: nil,
        high_24h: nil,
        low_24h: nil,
        timestamp: Time.now
      )
    end

    def fetch_candles(pair, interval, from: nil, to: nil, limit: nil)
      instrument = normalize_pair(pair)
      params = { granularity: interval }
      params[:from] = from.iso8601 if from
      params[:to] = to.iso8601 if to
      params[:count] = limit if limit

      data = http_client.get("/v3/instruments/#{instrument}/candles", params: params)

      data[:candidates].map do |c|
        Candle.new(
          pair: pair,
          interval: interval,
          open: c[:mid]&.dig(:o)&.to_d,
          high: c[:mid]&.dig(:h)&.to_d,
          low: c[:mid]&.dig(:l)&.to_d,
          close: c[:mid]&.dig(:c)&.to_d,
          volume: c[:volume]&.to_i,
          timestamp: Time.parse(c[:time]),
          closed: c[:complete] == true
        )
      end
    end

    def fetch_balance
      data = http_client.get("/v3/accounts/#{account_id}/summary")

      account = data[:account]

      Balance.new(
        total_equity: account[:balance]&.to_d,
        available_balance: account[:marginAvailable]&.to_d,
        unrealized_pnl: account[:unrealizedPL]&.to_d,
        currency: account[:currency],
        balances: {
          account[:currency] => {
            free: account[:marginAvailable]&.to_d,
            locked: account[:marginUsed]&.to_d,
            total: account[:balance]&.to_d
          }
        }
      )
    end

    def place_order(pair, side, type, quantity, price: nil, stop_price: nil, time_in_force: "GTC")
      instrument = normalize_pair(pair)

      order_params = {
        order: {
          instrument: instrument,
          units: side == "buy" ? quantity.to_i : -quantity.to_i,
          timeInForce: time_in_force == "IOC" ? "IOC" : "GTC",
          orderType: type == "market" ? "MARKET" : "LIMIT"
        }
      }

      if type == "limit"
        order_params[:order][:price] = price.to_s
      end

      if stop_price
        order_params[:order][:stopLossOnFill] = { price: stop_price.to_s }
      end

      data = http_client.post("/v3/accounts/#{account_id}/orders",
        params: nil,
        body: order_params.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      order_data = data[:orderFillTransaction] || data[:order]

      OrderResult.new(
        success: true,
        order_id: order_data[:id]&.to_s,
        side: side,
        type: type,
        pair: pair,
        quantity: quantity,
        price: order_data[:price]&.to_d,
        status: :filled,
        filled_quantity: order_data[:units]&.abs&.to_d,
        average_price: order_data[:price]&.to_d
      )
    rescue Exchanges::Error => e
      OrderResult.new(
        success: false,
        side: side,
        type: type,
        pair: pair,
        quantity: quantity,
        status: :failed,
        errors: [ e.message ]
      )
    end

    def cancel_order(order_id)
      data = http_client.put("/v3/accounts/#{account_id}/orders/#{order_id}/cancel")

      CancelResult.new(
        success: true,
        order_id: order_id,
        message: "Order cancelled"
      )
    rescue Exchanges::Error => e
      CancelResult.new(
        success: false,
        order_id: order_id,
        message: "Failed to cancel",
        errors: [ e.message ]
      )
    end

    def fetch_order_status(order_id)
      data = http_client.get("/v3/accounts/#{account_id}/orders/#{order_id}")

      order = data[:order]

      OrderStatus.new(
        order_id: order[:id]&.to_s,
        side: order[:units]&.to_i > 0 ? "buy" : "sell",
        type: order[:type]&.downcase,
        pair: denormalize_pair(order[:instrument]),
        quantity: order[:originalUnits]&.abs&.to_d,
        price: order[:price]&.to_d,
        status: order[:state] == "FILLED" ? :filled : :open,
        filled_quantity: order[:filledUnits]&.to_d,
        average_price: nil,
        created_at: Time.parse(order[:createTime]),
        updated_at: Time.parse(order[:createTime])
      )
    end

    def fee_schedule
      @fee_schedule ||= FeeSchedule.new(
        maker_rate: 0.0,
        taker_rate: 0.0,
        discount_info: nil,
        spread_based: true,
        typical_spreads: {
          "EUR/USD" => 0.11,
          "GBP/USD" => 0.15,
          "USD/JPY" => 0.08,
          "XAU/USD" => 2.5
        },
        currency: "USD"
      )
    end
  end
end
