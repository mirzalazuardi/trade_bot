class CreateExchangeCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :exchange_name, null: false
      t.string :api_key, limit: 500
      t.string :api_secret, limit: 1000
      t.string :account_id, limit: 100
      t.string :environment, default: "practice"
      t.boolean :is_active, default: true
      t.timestamps
    end

    add_index :exchange_credentials, [ :user_id, :exchange_name ], unique: true
  end
end
