class CreateEnums < ActiveRecord::Migration[8.1]
  def change
    create_enum :order_status, %w[pending submitted open partially_filled filled cancelled failed]
    create_enum :position_status, %w[open closed]
    create_enum :bot_mode, %w[auto semi_auto paper_trade backtest]
    create_enum :bot_status, %w[active paused stopped]
    create_enum :approval_status, %w[pending approved rejected expired]
    create_enum :ml_model_status, %w[testing active retired]
    create_enum :trade_mode, %w[live paper]
  end
end
