class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :exchange_name
      t.string :pair
      t.enum :status, enum_type: :position_status, default: "open"
      t.decimal :quantity, precision: 20, scale: 8
      t.decimal :price, precision: 20, scale: 8
      t.decimal :average_price, precision: 20, scale: 8
      t.decimal :gross_pnl, precision: 20, scale: 8, default: 0
      t.decimal :total_fees, precision: 20, scale: 8, default: 0
      t.decimal :net_pnl, precision: 20, scale: 8, default: 0

      t.timestamps
    end

    add_index :positions, [ :user_id, :exchange_name, :pair, :status ], unique: true, where: "(status = 'open')"
  end
end
