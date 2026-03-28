module Telegram
  class DailySummaryJob < ApplicationJob
    queue_as :default

    def perform
      User.where(telegram_enabled: true).find_each do |user|
        send_daily_summary(user)
      end
    end

    private

    def send_daily_summary(user)
      bot = TelegramBot.new
      return unless user.telegram_chat_id

      today_trades = user.trades.where("closed_at > ?", Time.current.beginning_of_day)
      today_pnl = today_trades.sum(:net_pnl)
      today_fees = today_trades.sum(:total_fees)
      trade_count = today_trades.count

      active_bots = user.bots.where(status: :active).count

      ai_filtered_count = Approval.where(bot: user.bots)
        .where("created_at > ?", Time.current.beginning_of_day)
        .where(status: :rejected)
        .count

      text = "<b>Daily Summary</b> 📊\n\n" \
             "Trades: #{trade_count}\n" \
             "Net PnL: #{today_pnl}\n" \
             "Fees: #{today_fees}\n" \
             "Active Bots: #{active_bots}\n" \
             "AI Filtered: #{ai_filtered_count}"

      bot.send_message(chat_id: user.telegram_chat_id, text: text)
    rescue => e
      Rails.logger.warn "Failed to send daily summary to user #{user.id}: #{e.message}"
    end
  end
end
