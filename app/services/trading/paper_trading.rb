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
      existing_position = find_open_paper_position

      if existing_position
        if existing_position.side != side_to_position_side
          close_position(existing_position)
          open_position
        else
          add_to_position(existing_position)
        end
      else
        open_position
      end
    end

    private

    def side_to_position_side
      @side == "buy" ? "long" : "short"
    end

    def find_open_paper_position
      Position.open_positions.find_by(
        user_id: @bot.user_id,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        bot_id: @bot.id
      )
    end

    def open_position
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

      position = Position.create!(
        user_id: @bot.user_id,
        bot_id: @bot.id,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        side: side_to_position_side,
        quantity: @quantity,
        average_price: @price,
        price: @price,
        status: :open
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
        exit_price: nil,
        closed_at: nil,
        total_fees: estimated_fee,
        net_pnl: 0
      )

      order.update!(trade_id: trade.id, position_id: position.id)
      order
    end

    def add_to_position(position)
      new_quantity = position.quantity + @quantity
      new_avg_price = ((position.average_price * position.quantity) + (@price * @quantity)) / new_quantity

      position.update!(
        quantity: new_quantity,
        average_price: new_avg_price,
        price: @price
      )

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
        filled_price: @price,
        position_id: position.id
      )

      order
    end

    def close_position(position)
      fees = estimated_fee
      pnl = calculate_pnl(position)

      position.close!(exit_price: @price, fees: fees)

      opposite_side = @side == "buy" ? "sell" : "buy"

      order = Order.create!(
        user_id: @bot.user_id,
        bot_id: @bot.id,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        side: opposite_side,
        quantity: position.quantity_was,
        price: @price,
        order_type: "limit",
        status: "filled",
        filled_quantity: position.quantity_was,
        filled_price: @price,
        position_id: position.id
      )

      trade = Trade.create!(
        user_id: @bot.user_id,
        bot_id: @bot.id,
        order_id: order.id,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        side: opposite_side,
        quantity: position.quantity_was,
        entry_price: position.average_price,
        exit_price: @price,
        closed_at: Time.current,
        total_fees: fees,
        net_pnl: pnl - fees
      )

      order.update!(trade_id: trade.id)
      order
    end

    def calculate_pnl(position)
      if position.long?
        (@price - position.average_price) * position.quantity
      else
        (position.average_price - @price) * position.quantity
      end
    end

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
