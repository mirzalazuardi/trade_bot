class CreateExchangeFees < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_fees do |t|
      t.string :exchange_name, null: false
      t.decimal :maker_rate, precision: 6, scale: 4, default: 0
      t.decimal :taker_rate, precision: 6, scale: 4, default: 0
      t.boolean :spread_based, default: false
      t.jsonb :typical_spreads, default: {}
      t.boolean :is_active, default: true
      t.timestamps
    end

    add_index :exchange_fees, :exchange_name, unique: true
  end
end
