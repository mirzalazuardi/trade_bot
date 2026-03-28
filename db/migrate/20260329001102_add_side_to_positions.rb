class AddSideToPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :positions, :side, :string, default: "long", null: false
  end
end
