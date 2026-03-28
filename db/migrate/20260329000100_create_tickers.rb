class CreateTickers < ActiveRecord::Migration[8.1]
  def change
    create_table :tickers do |t|
      t.string :exchange_name, null: false
      t.string :pair, null: false
      t.decimal :bid, precision: 20, scale: 8
      t.decimal :ask, precision: 20, scale: 8
      t.decimal :last, precision: 20, scale: 8
      t.decimal :volume_24h, precision: 30, scale: 8
      t.decimal :price_change_24h, precision: 20, scale: 8
      t.decimal :price_change_percent_24h, precision: 10, scale: 4
      t.decimal :high_24h, precision: 20, scale: 8
      t.decimal :low_24h, precision: 20, scale: 8
      t.bigint :timestamp, null: false
      t.timestamps
    end

    add_index :tickers, [ :exchange_name, :pair ], unique: true, name: "idx_ticker_unique"
    add_index :tickers, [ :updated_at ], name: "idx_ticker_stale"
  end
end
