module Trading
  class BacktestService
    def self.call(bot:, from_date:, to_date:)
      new(bot: bot, from_date: from_date, to_date: to_date).call
    end

    def initialize(bot:, from_date:, to_date:)
      @bot = bot
      @from_date = from_date
      @to_date = to_date
      @trades = []
      @cash = 10000
      @position = nil
    end

    def call
      candles = fetch_candles
      return { error: "No candles found" } if candles.empty?

      indicators = Indicators::Pipeline.build(@bot.exchange_name, @bot.pair, candles)

      candles.each_with_index do |candle, idx|
        next if idx < warmup_period

        state = build_state(candle, indicators, idx)
        signal = @bot.strategy_class.analyze(state)

        next if signal.hold?

        process_signal(signal, candle)
      end

      close_position(candles.last) if @position

      calculate_metrics
    end

    private

    def fetch_candles
      MarketData::QueryService.call(
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        interval: @bot.candle_interval || "1h",
        from: @from_date,
        to: @to_date
      ).candles
    end

    def warmup_period
      200
    end

    def build_state(candle, indicators, idx)
      OpenStruct.new(
        open: candle[:open],
        high: candle[:high],
        low: candle[:low],
        close: candle[:close],
        volume: candle[:volume],
        timestamp: candle[:timestamp],
        rsi: indicators.dig(:rsi, idx),
        macd: indicators.dig(:macd, idx),
        signal: indicators.dig(:macd_signal, idx),
        histogram: indicators.dig(:macd_histogram, idx),
        sma_20: indicators.dig(:sma_20, idx),
        sma_50: indicators.dig(:sma_50, idx),
        bb_upper: indicators.dig(:bb_upper, idx),
        bb_middle: indicators.dig(:bb_middle, idx),
        bb_lower: indicators.dig(:bb_lower, idx)
      )
    end

    def process_signal(signal, candle)
      price = signal.suggested_price || candle[:close]
      side = signal.buy? ? "buy" : "sell"

      if @position.nil?
        open_position(side: side, price: price, quantity: calculate_quantity(price), candle: candle)
      elsif @position[:side] != side
        close_position(candle)
        open_position(side: side, price: price, quantity: calculate_quantity(price), candle: candle)
      end
    end

    def open_position(side:, price:, quantity:, candle:)
      return if quantity.zero?

      fee = estimate_fee(quantity, price)
      cost = quantity * price + fee

      return if cost > @cash

      @cash -= cost
      @position = {
        side: side,
        quantity: quantity,
        entry_price: price,
        entry_time: candle[:timestamp],
        entry_candle: candle
      }
    end

    def close_position(candle)
      return unless @position

      price = candle[:close]
      fee = estimate_fee(@position[:quantity], price)
      proceeds = @position[:quantity] * price - fee

      if @position[:side] == "buy"
        pnl = proceeds - (@position[:quantity] * @position[:entry_price])
      else
        pnl = (@position[:quantity] * @position[:entry_price]) - proceeds
      end

      @trades << {
        side: @position[:side],
        quantity: @position[:quantity],
        entry_price: @position[:entry_price],
        exit_price: price,
        entry_time: @position[:entry_time],
        exit_time: candle[:timestamp],
        pnl: pnl,
        fees: fee
      }

      @cash += proceeds
      @position = nil
    end

    def calculate_quantity(price)
      return 0 if price.zero?

      allocation = @bot.risk_config&.position_size_percent || 10
      (@cash * (allocation / 100.0) / price).round(8)
    end

    def estimate_fee(quantity, price)
      FeeManagement::FeeCalculator.call(
        exchange_name: @bot.exchange_name,
        side: "sell",
        quantity: quantity,
        price: price
      ).total
    end

    def calculate_metrics
      total_pnl = @trades.sum { |t| t[:pnl] }
      total_fees = @trades.sum { |t| t[:fees] }
      win_count = @trades.count { |t| t[:pnl] > 0 }
      loss_count = @trades.count { |t| t[:pnl] < 0 }
      break_even = @trades.count { |t| t[:pnl] == 0 }

      {
        starting_cash: 10000,
        ending_cash: @cash,
        total_pnl: total_pnl,
        total_fees: total_fees,
        total_trades: @trades.size,
        win_count: win_count,
        loss_count: loss_count,
        break_even_count: break_even,
        win_rate: @trades.empty? ? 0 : (win_count.to_f / @trades.size * 100).round(2),
        avg_win: win_count.positive? ? (@trades.select { |t| t[:pnl] > 0 }.sum { |t| t[:pnl] } / win_count).round(2) : 0,
        avg_loss: loss_count.positive? ? (@trades.select { |t| t[:pnl] < 0 }.sum { |t| t[:pnl] } / loss_count).round(2) : 0,
        profit_factor: loss_count.positive? ? (@trades.select { |t| t[:pnl] > 0 }.sum { |t| t[:pnl] } / -@trades.select { |t| t[:pnl] < 0 }.sum { |t| t[:pnl] }).round(2) : 0,
        max_drawdown: calculate_max_drawdown,
        trades: @trades
      }
    end

    def calculate_max_drawdown
      running = 10000.0
      peak = running
      max_dd = 0

      @trades.each do |trade|
        running += trade[:pnl]
        peak = [peak, running].max
        dd = (peak - running) / peak * 100
        max_dd = [max_dd, dd].max
      end

      max_dd.round(2)
    end
  end
end
