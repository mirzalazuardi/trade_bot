class CreateCustomStrategies < ActiveRecord::Migration[8.1]
  def change
    create_table :custom_strategies do |t|
      t.string :name
      t.jsonb :config
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
