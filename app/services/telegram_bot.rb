class TelegramBot
  def initialize
    token = Rails.application.credentials.telegram_bot_token
    @bot = ::Telegram::Bot::Client.new(token) if token.present?
  end

  def api
    @bot&.api
  end

  def send_message(chat_id:, text:, parse_mode: "HTML", reply_markup: nil)
    return unless @bot

    api.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: parse_mode,
      reply_markup: reply_markup
    )
  rescue ::Telegram::Bot::Errors => e
    Rails.logger.warn "Telegram send_message failed: #{e.message}"
  end

  def answer_callback_query(callback_query_id:, text:)
    return unless @bot

    api.answer_callback_query(
      callback_query_id: callback_query_id,
      text: text
    )
  rescue ::Telegram::Bot::Errors => e
    Rails.logger.warn "Telegram answer_callback_query failed: #{e.message}"
  end

  def edit_message_text(chat_id:, message_id:, text:, parse_mode: "HTML", reply_markup: nil)
    return unless @bot

    api.edit_message_text(
      chat_id: chat_id,
      message_id: message_id,
      text: text,
      parse_mode: parse_mode,
      reply_markup: reply_markup
    )
  rescue ::Telegram::Bot::Errors => e
    Rails.logger.warn "Telegram edit_message_text failed: #{e.message}"
  end

  def send_trade_notification(user:, trade:)
    return unless user.telegram_chat_id

    pnl_emoji = trade.net_pnl >= 0 ? "📈" : "📉"
    text = "#{pnl_emoji} <b>Trade Closed</b>\n\n" \
           "Pair: #{trade.pair}\n" \
           "Side: #{trade.side}\n" \
           "Quantity: #{trade.quantity}\n" \
           "Entry: #{trade.entry_price}\n" \
           "Exit: #{trade.exit_price}\n" \
           "Gross PnL: #{trade.gross_pnl}\n" \
           "Fees: #{trade.total_fees}\n" \
           "<b>Net PnL: #{trade.net_pnl}</b>"

    send_message(chat_id: user.telegram_chat_id, text: text)
  end

  def send_risk_alert(user:, message:)
    return unless user.telegram_chat_id

    text = "⚠️ <b>Risk Alert</b>\n\n#{message}"
    send_message(chat_id: user.telegram_chat_id, text: text)
  end
end
