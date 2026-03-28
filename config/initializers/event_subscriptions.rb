Rails.application.config.after_initialize do
  ActiveSupport::Notifications.subscribe("order.filled") do |_name, payload|
    order = Order.find_by(id: payload[:order_id])
    return unless order

    trade = order.trade
    return unless trade

    TelegramBot.new.send_trade_notification(user: order.user, trade: trade)
    Dashboard::Broadcast.order_filled(order) if order.user
  end

  ActiveSupport::Notifications.subscribe("risk.violation") do |_name, payload|
    user = User.find_by(id: payload[:user_id])
    return unless user&.telegram_enabled?

    TelegramBot.new.send_risk_alert(user: user, message: payload[:message])
    Dashboard::Broadcast.risk_violation(payload[:bot], payload[:message].merge(user_id: user.id)) if payload[:bot]
  end

  ActiveSupport::Notifications.subscribe("approval.requested") do |_name, payload|
    approval = Approval.find_by(id: payload[:approval_id])
    return unless approval

    Telegram::ApprovalRequest.call(approval: approval)
  end

  ActiveSupport::Notifications.subscribe("signal.generated") do |_name, payload|
    bot = Bot.find_by(id: payload[:bot_id])
    return unless bot

    Dashboard::Broadcast.signal_generated(bot, payload[:signal]) if bot.user
  end
end
