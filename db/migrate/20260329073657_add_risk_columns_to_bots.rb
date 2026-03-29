class AddRiskColumnsToBots < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :max_position_pct, :decimal
    add_column :bots, :max_daily_loss_pct, :decimal
    add_column :bots, :max_open_orders, :integer
  end
end
