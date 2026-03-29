class AddTradeIdAndPositionIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :trade, foreign_key: true, type: :bigint, null: true
    add_reference :orders, :position, foreign_key: true, type: :bigint, null: true
  end
end
