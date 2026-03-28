module MarketData
  class UpdateMlOutcomesJob < ApplicationJob
    queue_as :default

    def perform(bot_id:, trade_id:)
      trade = Trade.find(trade_id)
      return unless trade.closed?

      MlPredictionLog.where(bot_id: bot_id, trade_executed: true)
        .where("created_at <= ?", trade.closed_at)
        .order(created_at: :desc)
        .first
        &.update!(
          trade_executed: true,
          trade_profitable: trade.net_pnl.to_f > 0
        )
    end

    def self.update_for_trade(trade)
      perform_async(bot_id: trade.bot_id, trade_id: trade.id)
    end
  end
end
