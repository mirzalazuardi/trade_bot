class AddCustomStrategyIdToBots < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :custom_strategy_id, :bigint
  end
end
