class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :bot_id, null: false
      t.string :exchange_name
      t.string :pair
      t.enum :status, enum_type: :order_status, default: "pending"
      t.string :order_type
      t.decimal :quantity, precision: 20, scale: 8
      t.decimal :price, precision: 20, scale: 8
      t.decimal :estimated_fee, precision: 20, scale: 8
      t.string :estimated_fee_currency
      t.string :native_order_id
      t.decimal :filled_quantity, precision: 20, scale: 8
      t.decimal :filled_price, precision: 20, scale: 8
      t.decimal :actual_fee_amount, precision: 20, scale: 8
      t.string :actual_fee_currency

      t.timestamps
    end

    add_foreign_key :orders, :bots, column: :bot_id
    add_index :orders, [ :exchange_name, :pair, :status ]
    add_index :orders, [ :bot_id, :status ]
    add_index :orders, :native_order_id
  end
end
