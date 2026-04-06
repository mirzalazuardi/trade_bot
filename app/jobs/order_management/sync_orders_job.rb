module OrderManagement
  class SyncOrdersJob < ApplicationJob
    queue_as :default

    discard_on Exchanges::ConnectionError

    def perform(bot_id:)
      bot = Bot.find(bot_id)
      return unless bot.active?

      credential = bot.user.exchange_credentials.active.find_by(exchange_name: bot.exchange_name)
      return unless credential

      adapter = Exchanges::Registry.get(bot.exchange_name).new(credential)

      Order.open_orders.where(bot: bot).each do |order|
        begin
          status = adapter.fetch_order_status(order.native_order_id, order.pair)

          case status.state
          when "filled"
            order.update!(
              status: :filled,
              filled_quantity: status.filled_quantity,
              filled_price: status.avg_price || order.price,
              actual_fee_amount: status.fee || order.estimated_fee,
              actual_fee_currency: status.fee_currency || order.pair.split("/").last
            )

            create_trade!(order: order)

            ActiveSupport::Notifications.publish("order.filled", order_id: order.id, bot_id: bot.id)

          when "partially_filled"
            order.update!(
              status: :partially_filled,
              filled_quantity: status.filled_quantity,
              filled_price: status.avg_price
            )

          when "cancelled"
            order.update!(status: :cancelled)
            ActiveSupport::Notifications.publish("order.cancelled", order_id: order.id, bot_id: bot.id)
          end
        rescue Exchanges::Error => e
          Rails.logger.warn "Failed to sync order #{order.id}: #{e.message}"
        end
      end
    end

    private

    def create_trade!(order:)
      Trade.create!(
        user: order.user,
        bot: order.bot,
        order: order,
        exchange_name: order.exchange_name,
        pair: order.pair,
        side: order.side,
        quantity: order.filled_quantity,
        entry_price: order.side_buy? ? order.price : order.filled_price,
        exit_price: order.side_sell? ? order.price : order.filled_price,
        gross_pnl: order.side_sell? ? (order.filled_price - order.price) * order.filled_quantity : 0,
        total_fees: order.actual_fee_amount || 0,
        net_pnl: (order.side_sell? ? (order.filled_price - order.price) * order.filled_quantity : 0) - (order.actual_fee_amount || 0),
        ml_confidence: order.bot.ml_confidence
      )
    end
  end
end
