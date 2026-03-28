module Dashboard
  class Broadcast
    def self.order_placed(order)
      broadcast("order_placed", {
        order_id: order.id,
        pair: order.pair,
        side: order.side,
        status: order.status
      })
    end

    def self.order_filled(order)
      broadcast("order_filled", {
        order_id: order.id,
        pair: order.pair,
        side: order.side,
        filled_at: order.filled_at
      })
    end

    def self.risk_violation(bot, message)
      broadcast("risk_violation", {
        bot_id: bot.id,
        pair: bot.pair,
        message: message
      })
    end

    def self.signal_generated(bot, signal)
      broadcast("signal_generated", {
        bot_id: bot.id,
        pair: bot.pair,
        signal_type: signal.type,
        confidence: signal.confidence
      })
    end

    private

    def self.broadcast(event, data)
      ActionCable.server.broadcast("dashboard:#{data[:user_id] || Current.user&.id}", {
        event: event,
        data: data,
        timestamp: Time.current
      }.compact)
    rescue => e
      Rails.logger.debug { "Broadcast failed: #{e.message}" }
    end
  end
end
