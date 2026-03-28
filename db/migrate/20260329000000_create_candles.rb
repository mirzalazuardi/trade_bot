class CreateCandles < ActiveRecord::Migration[8.1]
  def change
    create_table :candles do |t|
      t.string :exchange_name, null: false
      t.string :pair, null: false
      t.string :interval, null: false
      t.decimal :open, precision: 20, scale: 8, null: false
      t.decimal :high, precision: 20, scale: 8, null: false
      t.decimal :low, precision: 20, scale: 8, null: false
      t.decimal :close, precision: 20, scale: 8, null: false
      t.decimal :volume, precision: 30, scale: 8
      t.bigint :timestamp, null: false
      t.boolean :closed, default: true
      t.timestamps
    end

    add_index :candles, [ :exchange_name, :pair, :interval, :timestamp ], unique: true, name: "idx_candle_unique"
    add_index :candles, [ :exchange_name, :pair, :interval, :created_at ], name: "idx_candle_cleanup"
  end
end
