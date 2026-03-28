module Trading
  class ExecuteSignal
    def self.call(bot:, signal:)
      new(bot: bot, signal: signal).call
    end

    def initialize(bot:, signal:)
      @bot = bot
      @signal = signal
    end

    def call
      return Result.failure([ "Signal is hold" ]) if @signal.hold?

      side = @signal.buy? ? "buy" : "sell"
      price = @signal.suggested_price || current_price
      quantity = calculate_quantity(side: side, price: price)

      return Result.failure([ "Invalid quantity" ]) unless quantity.positive?

      pre_check = RiskManagement::PreTradeCheck.call(bot: @bot, side: side, amount: quantity, price: price)

      return Result.failure(pre_check.errors) unless pre_check.success

      if @bot.mode_paper_trade?
        execute_paper_trade(side: side, quantity: quantity, price: price)
      else
        execute_live_trade(side: side, quantity: quantity, price: price)
      end
    end

    private

    def execute_live_trade(side:, quantity:, price:)
      result = OrderManagement::PlaceOrder.call(
        bot: @bot,
        side: side,
        quantity: quantity,
        price: price,
        order_type: "limit"
      )

      if result.success
        ActiveSupport::Notifications.publish("order.placed", order_id: result.order.id, bot_id: @bot.id, signal: @signal)
      end

      result
    end

    def execute_paper_trade(side:, quantity:, price:)
      # Simulate order fill at suggested price
      paper_trade = Trading::PaperTrading.simulate(
        bot: @bot,
        side: side,
        quantity: quantity,
        price: price
      )

      ActiveSupport::Notifications.publish("order.placed", order_id: paper_trade.id, bot_id: @bot.id, signal: @signal)

      Result.success(order: paper_trade)
    end

    def current_price
      Ticker.find_by(exchange_name: @bot.exchange_name, pair: @bot.pair)&.last_price || 0
    end

    def calculate_quantity(side:, price:)
      return 0 if price.zero?

      allocation = @bot.risk_config&.position_size_percent || 10
      balance = fetch_balance

      (balance * (allocation / 100.0) / price).round(8)
    end

    def fetch_balance
      credential = @bot.user.exchange_credentials.active.find_by(exchange_name: @bot.exchange_name)
      return 0 unless credential

      adapter = Exchanges::Registry.get(@bot.exchange_name).new(credential)
      adapter.fetch_balance.available_balance
    end

    Result = Data.define(:success, :order, :errors) do
      def self.success(order:)
        new(success: true, order: order, errors: [])
      end

      def self.failure(errors)
        new(success: false, order: nil, errors: errors)
      end
    end
  end
end
