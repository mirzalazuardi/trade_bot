class CreateMlModels < ActiveRecord::Migration[8.1]
  def change
    create_table :ml_models do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.integer :version
      t.string :model_type
      t.date :training_date
      t.jsonb :performance_metrics, default: {}
      t.string :file_path
      t.jsonb :feature_list, default: []
      t.enum :status, enum_type: :ml_model_status, default: "testing"

      t.timestamps
    end

    add_index :ml_models, :training_date
    add_index :ml_models, [ :user_id, :name, :version ], unique: true
    add_index :ml_models, :status
  end
end
