class AddModeToTrades < ActiveRecord::Migration[8.1]
  def change
    add_column :trades, :mode, :enum, enum_type: "trade_mode", default: "live"
    change_column_default :trades, :mode, "live"
  end
end
