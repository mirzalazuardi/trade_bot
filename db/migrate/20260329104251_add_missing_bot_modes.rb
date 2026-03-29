class AddMissingBotModes < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER TYPE bot_mode ADD VALUE IF NOT EXISTS 'paper_trade'"
    execute "ALTER TYPE bot_mode ADD VALUE IF NOT EXISTS 'backtest'"
  end

  def down
    # PostgreSQL doesn't support removing enum values easily
  end
end
