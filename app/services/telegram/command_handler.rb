module Telegram
  class CommandHandler
    def initialize(user:, message:)
      @user = user
      @message = message
      @bot = TelegramBot.new
    end

    def process
      text = @message["text"].to_s
      chat_id = @message["chat"]["id"]

      case text
      when "/start"
        handle_start(chat_id)
      when "/status"
        handle_status(chat_id)
      when "/balance"
        handle_balance(chat_id)
      when "/bots"
        handle_bots(chat_id)
      when "/help"
        handle_help(chat_id)
      else
        @bot.send_message(chat_id: chat_id, text: "Unknown command. Use /help for available commands.")
      end
    end

    private

    def handle_start(chat_id)
      text = "Welcome to TradeBot! 🤖\n\n" \
             "Your trading bot is ready.\n\n" \
             "Commands:\n" \
             "/status - Portfolio overview\n" \
             "/balance - Balance per exchange\n" \
             "/bots - List active bots\n" \
             "/help - Show this help"

      @bot.send_message(chat_id: chat_id, text: text)
    end

    def handle_status(chat_id)
      total_pnl = @user.trades.sum(:net_pnl)
      total_fees = @user.trades.sum(:total_fees)
      active_bots = @user.bots.where(status: :active).count
      closed_today = @user.trades.where("closed_at > ?", Time.current.beginning_of_day).count

      text = "<b>Portfolio Status</b>\n\n" \
             "Net PnL: #{total_pnl}\n" \
             "Total Fees: #{total_fees}\n" \
             "Active Bots: #{active_bots}\n" \
             "Trades Today: #{closed_today}"

      @bot.send_message(chat_id: chat_id, text: text)
    end

    def handle_balance(chat_id)
      credentials = @user.exchange_credentials.active.includes(:exchange_name)

      return @bot.send_message(chat_id: chat_id, text: "No exchange credentials configured.") if credentials.empty?

      text = "<b>Balances</b>\n\n"

      credentials.each do |cred|
        begin
          adapter = Exchanges::Registry.get(cred.exchange_name).new(cred)
          balance = adapter.fetch_balance
          text += "#{cred.exchange_name.titleize}: #{balance.available_balance} #{balance.currency}\n"
        rescue => e
          text += "#{cred.exchange_name.titleize}: Error - #{e.message}\n"
        end
      end

      @bot.send_message(chat_id: chat_id, text: text)
    end

    def handle_bots(chat_id)
      bots = @user.bots.order(created_at: :desc).limit(10)

      return @bot.send_message(chat_id: chat_id, text: "No bots configured.") if bots.empty?

      text = "<b>Your Bots</b>\n\n"

      bots.each do |bot|
        status_emoji = bot.active? ? "🟢" : bot.paused? ? "🟡" : "🔴"
        ai_emoji = bot.ai_enabled ? "🤖" : "⚙️"
        text += "#{status_emoji} #{bot.exchange_name}/#{bot.pair} (#{bot.strategy})\n" \
                "   Mode: #{bot.mode}, AI: #{ai_emoji}\n\n"
      end

      @bot.send_message(chat_id: chat_id, text: text)
    end

    def handle_help(chat_id)
      text = "<b>Available Commands</b>\n\n" \
             "/start - Welcome message\n" \
             "/status - Portfolio overview\n" \
             "/balance - Balance per exchange\n" \
             "/bots - List active bots\n" \
             "/help - Show this help"

      @bot.send_message(chat_id: chat_id, text: text)
    end
  end
end
