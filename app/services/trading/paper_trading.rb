module Trading
  class PaperTrading
    def self.simulate(bot:, side:, quantity:, price:)
      new(bot: bot, side: side, quantity: quantity, price: price).simulate
    end

    def initialize(bot:, side:, quantity:, price:)
      @bot = bot
      @side = side
      @quantity = quantity
      @price = price
    end

    def simulate
      order = Order.create!(
        user_id: @bot.user_id,
        bot_id: @bot.id,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        side: @side,
        quantity: @quantity,
        price: @price,
        order_type: "limit",
        status: "filled",
        filled_quantity: @quantity,
        filled_price: @price
      )

      trade = Trade.create!(
        user_id: @bot.user_id,
        bot_id: @bot.id,
        order_id: order.id,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        side: @side,
        quantity: @quantity,
        entry_price: @price,
        exit_price: @price,
        closed_at: Time.current,
        total_fees: estimated_fee,
        net_pnl: 0
      )

      order.update!(trade_id: trade.id)
      order
    end

    private

    def estimated_fee
      FeeManagement::FeeCalculator.call(
        exchange_name: @bot.exchange_name,
        side: @side,
        quantity: @quantity,
        price: @price
      ).total
    end
  end
end
