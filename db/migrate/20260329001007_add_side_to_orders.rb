class AddSideToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :side, :string, null: false, default: "buy"
  end
end
