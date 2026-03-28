class CreateTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trades do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :bot_id, null: false
      t.string :exchange_name
      t.string :pair
      t.string :side
      t.bigint :order_id, null: false
      t.decimal :entry_price, precision: 20, scale: 8
      t.decimal :exit_price, precision: 20, scale: 8
      t.decimal :quantity, precision: 20, scale: 8
      t.decimal :gross_pnl, precision: 20, scale: 8
      t.decimal :total_fees, precision: 20, scale: 8
      t.decimal :net_pnl, precision: 20, scale: 8
      t.integer :ml_model_id
      t.decimal :ml_confidence, precision: 5, scale: 2
      t.datetime :closed_at

      t.timestamps
    end

    add_foreign_key :trades, :bots, column: :bot_id
    add_foreign_key :trades, :orders, column: :order_id
    add_index :trades, [ :user_id, :closed_at ]
    add_index :trades, [ :bot_id, :closed_at ]
  end
end
