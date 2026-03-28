class CreateBots < ActiveRecord::Migration[8.1]
  def change
    create_table :bots do |t|
      t.references :user, null: false, foreign_key: true
      t.string :exchange_name
      t.string :pair
      t.string :strategy
      t.enum :mode, enum_type: :bot_mode, default: "auto"
      t.enum :status, enum_type: :bot_status, default: "active"
      t.boolean :ai_enabled, default: false
      t.integer :ml_model_id
      t.decimal :ml_high_threshold, precision: 5, scale: 2, default: 0.8
      t.decimal :ml_low_threshold, precision: 5, scale: 2, default: 0.3

      t.timestamps
    end

    add_index :bots, [ :user_id, :status ]
    add_index :bots, [ :exchange_name, :status ]
  end
end
