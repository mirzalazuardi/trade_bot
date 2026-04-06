module Trading
  class BotScheduler < ApplicationJob
    queue_as :default

    def perform
      Bot.active_bots.find_each do |bot|
        EvaluateBotJob.perform_later(bot_id: bot.id, timeframe: "1h")
      end
    end
  end
end
