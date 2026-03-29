class TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :webhook
  before_action :verify_telegram_request, only: :webhook

  def webhook
    update = params[:message]&.to_h || params[:callback_query]&.to_h

    return render json: :ok unless update

    if update["message"]
      process_message(update["message"])
    elsif update["callback_query"]
      process_callback(update["callback_query"])
    end

    render json: :ok
  end

  private

  def process_message(message)
    text = message["text"].to_s
    chat_id = message["chat"]["id"]

    user = User.find_by(telegram_chat_id: chat_id.to_s)

    return handle_unverified_user(chat_id) unless user

    if text.start_with?("/")
      Telegram::CommandHandler.new(user: user, message: message).process
    end
  end

  def process_callback(callback)
    callback_data = callback["data"]
    message = callback["message"]
    chat_id = message["chat"]["id"]
    message_id = message["message_id"]

    user = User.find_by(telegram_chat_id: chat_id.to_s)
    return unless user

    case callback_data
    when /^approve_(\d+)$/
      approval_id = $1
      handle_approval(approval_id, :approved, user, message_id)
    when /^reject_(\d+)$/
      approval_id = $1
      handle_approval(approval_id, :rejected, user, message_id)
    end
  end

  def handle_approval(approval_id, action, user, message_id)
    approval = Approval.find_by(id: approval_id, user: user)
    return unless approval&.pending?

    approval.send("#{action}!")
    TelegramBot.new.edit_message_text(
      chat_id: user.telegram_chat_id,
      message_id: message_id,
      text: "Trade #{action}: #{approval.side} #{approval.quantity} #{approval.pair} @ #{approval.price}"
    )

    if action == :approved
      bot = approval.bot
      signal = Strategy::Signal.new(
        type: approval.side == "buy" ? Strategy::BUY : Strategy::SELL,
        confidence: approval.ml_confidence || 0.5,
        reason: "Approved via Telegram"
      )
      Trading::ExecuteSignal.call(bot: bot, signal: signal)
    end
  end

  def handle_unverified_user(chat_id)
    TelegramBot.new.send_message(
      chat_id: chat_id,
      text: "Please link your Telegram account in the TradeBot dashboard."
    )
  end

  def verify_telegram_request
    token = Rails.application.credentials.telegram_bot_token
    return true if token.blank?

    # For production, implement proper Telegram auth verification
    # https://core.telegram.org/widgets/login#checking-authentication-result
    true
  end
end
