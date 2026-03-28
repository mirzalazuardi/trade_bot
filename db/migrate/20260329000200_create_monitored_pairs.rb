class CreateMonitoredPairs < ActiveRecord::Migration[8.1]
  def change
    create_table :monitored_pairs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :exchange_name, null: false
      t.string :pair, null: false
      t.string :interval, default: "1h"
      t.boolean :collect_candles, default: true
      t.boolean :collect_ticker, default: true
      t.integer :collect_interval, default: 60
      t.boolean :is_active, default: true
      t.timestamps
    end

    add_index :monitored_pairs, [ :user_id, :exchange_name, :pair ], unique: true, name: "idx_monitored_pair_unique"
  end
end
