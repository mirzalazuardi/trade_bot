Rails.application.config.after_initialize do
  ActiveSupport::Notifications.subscribe("order.filled") do |_name, payload|
    order = Order.find_by(id: payload[:order_id])
    return unless order

    trade = order.trade
    return unless trade

    TelegramBot.new.send_trade_notification(user: order.user, trade: trade)
  end

  ActiveSupport::Notifications.subscribe("risk.violation") do |_name, payload|
    user = User.find_by(id: payload[:user_id])
    return unless user&.telegram_enabled?

    TelegramBot.new.send_risk_alert(user: user, message: payload[:message])
  end

  ActiveSupport::Notifications.subscribe("approval.requested") do |_name, payload|
    approval = Approval.find_by(id: payload[:approval_id])
    return unless approval

    Telegram::ApprovalRequest.call(approval: approval)
  end
end
