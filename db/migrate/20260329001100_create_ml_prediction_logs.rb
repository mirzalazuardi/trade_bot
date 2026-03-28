class CreateMlPredictionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ml_prediction_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :bot, null: false, foreign_key: true
      t.references :ml_model, null: false, foreign_key: true
      t.decimal :confidence, precision: 5, scale: 2
      t.string :signal_type
      t.jsonb :features_snapshot, default: {}
      t.boolean :trade_executed, default: false
      t.boolean :trade_profitable, default: false

      t.timestamps
    end

    add_index :ml_prediction_logs, [ :bot_id, :created_at ]
    add_index :ml_prediction_logs, [ :ml_model_id, :created_at ]
  end
end
