module Exchanges
  class Tokocrypto
    include Base

    BASE_URL = "https://www.tokocrypto.com"

    attr_reader :api_key, :api_secret, :http_client

    def initialize(api_key: nil, api_secret: nil)
      @api_key = api_key
      @api_secret = api_secret
      @http_client = HttpClient.new(
        base_url: BASE_URL,
        api_key: api_key
      )
    end

    def self.required_credentials
      %i[api_key api_secret]
    end

    def self.supported_pairs
      @supported_pairs ||= begin
        fetch_all_pairs.map { |p| p[:symbol] }
      rescue
        %w[BTC/USDT ETH/USDT BNB/USDT XRP/USDT TKO/USDT]
      end
    end

    def normalize_pair(pair)
      pair.delete("/").uppercase
    end

    def denormalize_pair(pair)
      base = pair[0..-5]
      quote = pair[-4..-1]
      "#{base}/#{quote}"
    end

    def fetch_ticker(pair)
      symbol = normalize_pair(pair)
      data = http_client.get("/api/v1/ticker/24h", params: { symbol: symbol })

      Ticker.new(
        pair: pair,
        bid: data[:bidPrice]&.to_d,
        ask: data[:askPrice]&.to_d,
        last: data[:lastPrice]&.to_d,
        volume_24h: data[:volume]&.to_d,
        price_change_24h: data[:priceChange]&.to_d,
        price_change_percent_24h: data[:priceChangePercent]&.to_d,
        high_24h: data[:highPrice]&.to_d,
        low_24h: data[:lowPrice]&.to_d,
        timestamp: Time.now
      )
    end

    def fetch_candles(pair, interval, from: nil, to: nil, limit: nil)
      symbol = normalize_pair(pair)
      params = { symbol: symbol, interval: interval }
      params[:startTime] = (from.to_i * 1000) if from
      params[:endTime] = (to.to_i * 1000) if to
      params[:limit] = limit || 500

      data = http_client.get("/api/v1/klines", params: params)

      data.map do |c|
        Candle.new(
          pair: pair,
          interval: interval,
          open: c[1]&.to_d,
          high: c[2]&.to_d,
          low: c[3]&.to_d,
          close: c[4]&.to_d,
          volume: c[5]&.to_d,
          timestamp: Time.at(c[0]&.to_i / 1000),
          closed: true
        )
      end
    end

    def fetch_balance
      timestamp = timestamp_ms
      params = { timestamp: timestamp }
      params[:signature] = sign_params(params)

      data = http_client.get("/api/v3/account", params: params)

      balances = data[:balances].each_with_object({}) do |b, hash|
        free = b[:free].to_d
        locked = b[:locked].to_d
        hash[b[:asset]] = { free: free, locked: locked, total: free + locked } if free.positive? || locked.positive?
      end

      total_equity = balances.dig("USDT", :total) || 0

      Balance.new(
        total_equity: total_equity,
        available_balance: balances.dig("USDT", :free) || total_equity,
        unrealized_pnl: 0,
        currency: "USDT",
        balances: balances
      )
    end

    def place_order(pair, side, type, quantity, price: nil, stop_price: nil, time_in_force: "GTC")
      symbol = normalize_pair(pair)
      params = {
        symbol: symbol,
        side: side.upcase,
        type: type.upcase,
        quantity: quantity
      }
      params[:price] = price if price
      params[:stopPrice] = stop_price if stop_price
      params[:timeInForce] = time_in_force if price && type == "limit"

      timestamp = timestamp_ms
      params[:timestamp] = timestamp
      params[:signature] = sign_params(params)

      data = http_client.post("/api/v3/order", params: params)

      OrderResult.new(
        success: true,
        order_id: data[:orderId]&.to_s,
        client_order_id: data[:clientOrderId],
        side: data[:side]&.downcase,
        type: data[:type]&.downcase,
        pair: pair,
        quantity: data[:origQty]&.to_d,
        price: data[:price]&.to_d,
        status: map_order_status(data[:status]),
        filled_quantity: data[:executedQty]&.to_d,
        average_price: data[:price]&.to_d
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
      params = { orderId: order_id }
      timestamp = timestamp_ms
      params[:timestamp] = timestamp
      params[:signature] = sign_params(params)

      data = http_client.delete("/api/v3/order", params: params)

      CancelResult.new(
        success: true,
        order_id: data[:orderId]&.to_s,
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
      params = { orderId: order_id }
      timestamp = timestamp_ms
      params[:timestamp] = timestamp
      params[:signature] = sign_params(params)

      data = http_client.get("/api/v3/order", params: params)

      OrderStatus.new(
        order_id: data[:orderId]&.to_s,
        client_order_id: data[:clientOrderId],
        side: data[:side]&.downcase,
        type: data[:type]&.downcase,
        pair: denormalize_pair(data[:symbol]),
        quantity: data[:origQty]&.to_d,
        price: data[:price]&.to_d,
        status: map_order_status(data[:status]),
        filled_quantity: data[:executedQty]&.to_d,
        average_price: data[:price]&.to_d,
        created_at: Time.at(data[:time]&.to_i / 1000),
        updated_at: Time.at(data[:updateTime]&.to_i / 1000)
      )
    end

    def fee_schedule
      @fee_schedule ||= FeeSchedule.new(
        maker_rate: 0.001,
        taker_rate: 0.001,
        discount_info: { tko_discount_available: true },
        spread_based: false,
        typical_spreads: {
          "BTC/USDT" => 0.01,
          "ETH/USDT" => 0.01
        },
        currency: "USDT"
      )
    end

    private

    def timestamp_ms
      (Time.now.to_f * 1000).to_i
    end

    def sign_params(params)
      query_string = params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}=#{v}" }.join("&")
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, api_secret, query_string)
    end

    def map_order_status(status)
      case status
      when "NEW" then :open
      when "PARTIALLY_FILLED" then :partially_filled
      when "FILLED" then :filled
      when "CANCELED" then :cancelled
      when "PENDING_CANCEL" then :pending
      when "REJECTED" then :failed
      when "EXPIRED" then :failed
      else :pending
      end
    end

    def fetch_all_pairs
      data = http_client.get("/api/v1/exchangeInfo")
      data[:symbols].select { |s| s[:status] == "TRADING" }
    rescue
      []
    end
  end
end
