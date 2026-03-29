class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @total_pnl = current_user.trades.sum(:net_pnl)
    @total_fees = current_user.trades.sum(:total_fees)
    @active_bots = current_user.bots.where(status: :active).count
    @recent_trades = current_user.trades.recent.limit(5)
    @today_pnl = current_user.trades.where("closed_at > ?", Time.current.beginning_of_day).sum(:net_pnl)
    @today_trades = current_user.trades.where("closed_at > ?", Time.current.beginning_of_day).count

    @balances = fetch_balances
    @market_prices = fetch_market_prices
    @market_context = fetch_market_context
  end

  private

  def fetch_balances
    credentials = current_user.exchange_credentials.active.includes(:exchange_name)
    credentials.map do |cred|
      begin
        adapter = Exchanges::Registry.get(cred.exchange_name).new(cred)
        balance = adapter.fetch_balance
        { exchange: cred.exchange_name, balance: balance.available_balance, currency: balance.currency }
      rescue
        { exchange: cred.exchange_name, balance: "Error", currency: "" }
      end
    end
  end

  MAJOR_MARKETS = {
    crypto: [
      { pair: "BTC/USDT", exchange: "binance" },
      { pair: "ETH/USDT", exchange: "binance" },
      { pair: "SOL/USDT", exchange: "binance" },
      { pair: "BNB/USDT", exchange: "binance" },
      { pair: "XRP/USDT", exchange: "binance" },
      { pair: "ADA/USDT", exchange: "binance" },
      { pair: "DOGE/USDT", exchange: "binance" },
      { pair: "DOT/USDT", exchange: "binance" }
    ],
    forex: [
      { pair: "EUR/USD", exchange: "oanda" },
      { pair: "GBP/USD", exchange: "oanda" },
      { pair: "USD/JPY", exchange: "oanda" },
      { pair: "USD/CHF", exchange: "oanda" },
      { pair: "AUD/USD", exchange: "oanda" },
      { pair: "USD/CAD", exchange: "oanda" }
    ],
    commodities: [
      { pair: "XAU/USD", exchange: "oanda" },
      { pair: "XAG/USD", exchange: "oanda" }
    ]
  }

  def fetch_market_prices
    prices = { crypto: [], forex: [], commodities: [] }

    MAJOR_MARKETS[:crypto].each do |market|
      begin
        adapter = Exchanges::Registry.get("binance").new(nil)
        ticker = adapter.fetch_ticker(market[:pair])
        prices[:crypto] << {
          pair: market[:pair],
          price: ticker.last,
          change: ticker.price_change_percent_24h
        }
      rescue
        prices[:crypto] << { pair: market[:pair], price: nil, change: nil }
      end
    end

    MAJOR_MARKETS[:forex].each do |market|
      begin
        adapter = Exchanges::Registry.get("oanda").new(nil)
        ticker = adapter.fetch_ticker(market[:pair])
        prices[:forex] << {
          pair: market[:pair],
          price: ticker.last,
          change: ticker.price_change_percent_24h
        }
      rescue
        prices[:forex] << { pair: market[:pair], price: nil, change: nil }
      end
    end

    MAJOR_MARKETS[:commodities].each do |market|
      begin
        adapter = Exchanges::Registry.get("oanda").new(nil)
        ticker = adapter.fetch_ticker(market[:pair])
        prices[:commodities] << {
          pair: market[:pair],
          price: ticker.last,
          change: ticker.price_change_percent_24h
        }
      rescue
        prices[:commodities] << { pair: market[:pair], price: nil, change: nil }
      end
    end

    prices
  end

  def fetch_market_context
    MarketIntelligence::MarketContext.call
  rescue => e
    Rails.logger.error("MarketContext error: #{e.message}")
    {
      risk_regime: :unknown,
      calendar_risk: :unknown,
      upcoming_events: [],
      avoid_pairs: [],
      polymarket_signals: [],
      polymarket_shifts: [],
      bias: :neutral,
      size_modifier: 1.0,
      summary: "Market intelligence unavailable"
    }
  end
end
