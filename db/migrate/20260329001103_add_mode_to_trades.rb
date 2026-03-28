class AddModeToTrades < ActiveRecord::Migration[8.1]
  def change
    create_enum :trade_mode, %w[live paper]
    add_column :trades, :mode, :enum, enum_type: "trade_mode", default: "live"
  end
end
