module Trading
  class BotScheduler
    include SolidQueue::Job

    recurring_job every: "5m", retry: 3 do
      Bot.active_bots.find_each do |bot|
        EvaluateBotJob.perform_later(bot_id: bot.id, timeframe: "1h")
      end
    end
  end
end
