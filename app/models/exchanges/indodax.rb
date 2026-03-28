module Exchanges
  class Indodax
    include Base

    BASE_URL = "https://indodax.com"

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
        fetch_all_pairs.map { |p| "#{p[:trading_pair].split('_')[0]}/#{p[:trading_pair].split('_')[1]}" }
      rescue
        %w[BTC/IDR ETH/IDR BNB/IDR XRP/IDR DOGE/IDR
           ADA/IDR MATIC/IDR SOL/IDR DOT/IDR LTC/IDR]
      end
    end

    def normalize_pair(pair)
      pair.delete("/").upcase + "_IDR"
    end

    def denormalize_pair(pair)
      base, quote = pair.split("_IDR")
      "#{base}/IDR"
    end

    def fetch_ticker(pair)
      symbol = normalize_pair(pair)
      data = http_client.get("/api/#{symbol}/ticker")

      ticker_data = data[:ticker]

      Ticker.new(
        pair: pair,
        bid: ticker_data[:buy]&.to_d,
        ask: ticker_data[:sell]&.to_d,
        last: ticker_data[:last]&.to_d,
        volume_24h: ticker_data[:vol_btc]&.to_d,
        price_change_24h: nil,
        price_change_percent_24h: nil,
        high_24h: ticker_data[:high]&.to_d,
        low_24h: ticker_data[:low]&.to_d,
        timestamp: Time.now
      )
    end

    def fetch_candles(pair, interval, from: nil, to: nil, limit: nil)
      symbol = normalize_pair(pair)
      params = { pair: symbol }

      interval_map = {
        "1m" => "1m",
        "5m" => "5m",
        "15m" => "15m",
        "30m" => "30m",
        "1h" => "1h",
        "4h" => "4h",
        "1d" => "1d"
      }
      params[:interval] = interval_map[interval] || "1m"
      params[:limit] = limit || 500

      data = http_client.get("/api/#{symbol}/klines", params: params)

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
      params = { method: "getInfo" }
      signed_params = sign_params(params)
      data = http_client.post("/tmapi", params: signed_params)

      balances = {}
      data[:return].each do |key, value|
        next if key == "funds" && value.empty?

        if key == "funds"
          value.each do |asset, amount|
            balances[asset.upcase] = {
              free: amount.to_d,
              locked: 0,
              total: amount.to_d
            }
          end
        elsif key == "open_orders"
          # Open orders balance is locked
        end
      end

      total_equity = balances.dig("IDR", :total) || 0

      Balance.new(
        total_equity: total_equity,
        available_balance: balances.dig("IDR", :free) || total_equity,
        unrealized_pnl: 0,
        currency: "IDR",
        balances: balances
      )
    end

    def place_order(pair, side, type, quantity, price: nil, stop_price: nil, time_in_force: "GTC")
      symbol = normalize_pair(pair)

      params = {
        method: side == "buy" ? "buy" : "sell",
        pair: symbol,
        type: type == "market" ? "market" : "limit",
        rate: price || 0,
        amount: quantity
      }
      signed_params = sign_params(params)
      data = http_client.post("/tmapi", params: signed_params)

      order_data = data[:return][:order]

      OrderResult.new(
        success: true,
        order_id: order_data[:order_id]&.to_s,
        side: side,
        type: type,
        pair: pair,
        quantity: order_data[:amount]&.to_d,
        price: order_data[:rate]&.to_d,
        status: :open,
        filled_quantity: 0,
        average_price: nil
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
      params = {
        method: "cancelOrder",
        order_id: order_id
      }
      signed_params = sign_params(params)
      data = http_client.post("/tmapi", params: signed_params)

      CancelResult.new(
        success: data[:success] == 1,
        order_id: order_id,
        message: data[:return]&.dig(:message) || "Order cancelled"
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
      params = { method: "getOrderHistory" }
      signed_params = sign_params(params)
      data = http_client.post("/tmapi", params: signed_params)

      order_data = data[:return]&.dig(:orders, order_id.to_s)

      return raise Exchanges::OrderNotFoundError, "Order not found" unless order_data

      OrderStatus.new(
        order_id: order_data[:order_id]&.to_s,
        side: order_data[:type] == "buy" ? "buy" : "sell",
        type: order_data[:order_type] == "market" ? "market" : "limit",
        pair: denormalize_pair(order_data[:pair]),
        quantity: order_data[:amount]&.to_d,
        price: order_data[:rate]&.to_d,
        status: order_data[:status] == "cancel" ? :cancelled : :open,
        filled_quantity: order_data[:amount]&.to_d - order_data[:remaining]&.to_d,
        average_price: nil,
        created_at: Time.at(order_data[:timestamp]&.to_i),
        updated_at: Time.now
      )
    end

    def fee_schedule
      @fee_schedule ||= FeeSchedule.new(
        maker_rate: 0.0,
        taker_rate: 0.003,
        discount_info: nil,
        spread_based: false,
        commission_per_unit: { "IDR" => 10_000 },
        typical_spreads: {},
        currency: "IDR"
      )
    end

    private

    def sign_params(params)
      params[:method] ||= "getInfo"
      params[:nonce] = (Time.now.to_f * 1000).to_i

      post_data = params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}=#{v}" }.join("&")
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA512.new, api_secret, post_data)

      params[:api_key] = api_key
      params[:signature] = signature
      params
    end

    def fetch_all_pairs
      data = http_client.get("/api/pairs")
      data[:pairs]
    rescue
      []
    end
  end
end
