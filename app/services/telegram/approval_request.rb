module Telegram
  class ApprovalRequest
    def self.call(approval:)
      new(approval: approval).send_request
    end

    def initialize(approval:)
      @approval = approval
      @user = approval.user
      @bot = TelegramBot.new
    end

    def send_request
      return unless @user.telegram_enabled?

      text = build_approval_message

      reply_markup = build_inline_keyboard

      @bot.send_message(
        chat_id: @user.telegram_chat_id,
        text: text,
        reply_markup: reply_markup
      )
    end

    private

    def build_approval_message
      bot = @approval.bot
      fee_text = @approval.estimated_fee ? " (~#{@approval.estimated_fee} fee)" : ""
      ml_text = @approval.ml_confidence ? " | ML: #{(@approval.ml_confidence * 100).round(0)}%" : ""

      "<b>Trade Approval Request</b>\n\n" \
        "#{@approval.side.upcase} #{@approval.quantity} #{bot.pair}\n" \
        "Price: #{@approval.price}#{fee_text}#{ml_text}\n" \
        "Bot: #{bot.exchange_name}/#{bot.strategy}\n" \
        "Expires: #{@approval.expires_at&.strftime('%H:%M')}"
    end

    def build_inline_keyboard
      {
        inline_keyboard: [
          [
            { text: "✅ Approve", callback_data: "approve_#{@approval.id}" },
            { text: "❌ Reject", callback_data: "reject_#{@approval.id}" }
          ]
        ]
      }
    end
  end
end
