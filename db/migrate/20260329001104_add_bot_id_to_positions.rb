class AddBotIdToPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :positions, :bot_id, :bigint
  end
end
